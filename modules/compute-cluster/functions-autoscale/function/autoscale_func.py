import json
import os
from datetime import datetime, timedelta, timezone

import oci
from fdk import response


ACTIVE_JOB_STATES = {"ACCEPTED", "IN_PROGRESS", "CANCELING"}


def _env(name: str, default: str = "") -> str:
    return os.getenv(name, default).strip()


def _log(message: str) -> None:
    print(f"[autoscale-function] {message}", flush=True)


def _list_memory_instances(compute_client, compartment_id: str):
    instances = oci.pagination.list_call_get_all_results(
        compute_client.list_instances,
        compartment_id=compartment_id,
        lifecycle_state="RUNNING",
    ).data

    memory_instances = []
    for inst in instances:
        tags = inst.freeform_tags or {}
        if tags.get("node_pool") == "rdma-memory" and tags.get("node_role") == "memory":
            memory_instances.append(inst)
    return memory_instances


def _latest_memory_value(monitoring_client, compartment_id: str, instance_id: str, window_minutes: int):
    end_time = datetime.now(timezone.utc)
    start_time = end_time - timedelta(minutes=window_minutes)
    query = f'MemoryUtilization[{window_minutes}m]{{resourceId = "{instance_id}"}}.mean()'

    details = oci.monitoring.models.SummarizeMetricsDataDetails(
        namespace="oci_computeagent",
        query=query,
        start_time=start_time,
        end_time=end_time,
    )
    result = monitoring_client.summarize_metrics_data(compartment_id=compartment_id, summarize_metrics_data_details=details).data
    if not result:
        return None

    points = sorted(result[0].aggregated_datapoints or [], key=lambda p: p.timestamp)
    if not points:
        return None
    return points[-1].value


def _create_rm_apply_job(rm_client, stack_id: str, next_count: int):
    job = oci.resource_manager.models.CreateJobDetails(
        stack_id=stack_id,
        display_name=f"rdma-memory-autoscale-{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}",
        job_operation_details=oci.resource_manager.models.CreateApplyJobOperationDetails(
            execution_plan_strategy="AUTO_APPROVED",
            is_provider_upgrade_required=False,
            variables={"memory_node_count": str(next_count)},
        ),
    )
    return rm_client.create_job(create_job_details=job).data


def handler(ctx, data=None):
    try:
        signer = oci.auth.signers.get_resource_principals_signer()

        region = _env("RESOURCE_MANAGER_REGION")
        compartment_id = _env("COMPARTMENT_OCID")
        stack_id = _env("RESOURCE_MANAGER_STACK_ID")
        stack_compartment = _env("RESOURCE_MANAGER_STACK_COMPARTMENT", compartment_id)
        threshold = float(_env("MEMORY_SCALE_THRESHOLD_PERCENT", "80"))
        window_minutes = int(_env("MEMORY_SCALE_WINDOW_MINUTES", "5"))
        scale_rule = _env("MEMORY_SCALE_RULE", "all_nodes")
        cooldown_minutes = int(_env("MEMORY_SCALE_COOLDOWN_MINUTES", "20"))
        max_count = int(_env("MEMORY_NODE_MAX_COUNT", "8"))
        dry_run = _env("MEMORY_AUTOSCALE_DRY_RUN", "false").lower() == "true"

        if not (region and compartment_id and stack_id):
            raise ValueError("Missing required environment variables for autoscaler function.")

        compute_client = oci.core.ComputeClient(config={}, signer=signer, service_endpoint=f"https://iaas.{region}.oraclecloud.com")
        monitoring_client = oci.monitoring.MonitoringClient(config={}, signer=signer, service_endpoint=f"https://telemetry.{region}.oraclecloud.com")
        rm_client = oci.resource_manager.ResourceManagerClient(config={}, signer=signer, service_endpoint=f"https://resourcemanager.{region}.oraclecloud.com")

        memory_instances = _list_memory_instances(compute_client, compartment_id)
        current_count = len(memory_instances)
        _log(f"memory nodes found: {current_count}")

        if current_count == 0:
            return response.Response(ctx, response_data=json.dumps({"status": "no-memory-nodes"}), headers={"Content-Type": "application/json"})
        if current_count >= max_count:
            return response.Response(ctx, response_data=json.dumps({"status": "at-max-count", "count": current_count}), headers={"Content-Type": "application/json"})

        jobs = oci.pagination.list_call_get_all_results(
            rm_client.list_jobs,
            compartment_id=stack_compartment,
            stack_id=stack_id,
        ).data
        active_jobs = [j for j in jobs if j.lifecycle_state in ACTIVE_JOB_STATES]
        if active_jobs:
            return response.Response(ctx, response_data=json.dumps({"status": "active-rm-job"}), headers={"Content-Type": "application/json"})

        succeeded_apply_jobs = sorted(
            [j for j in jobs if j.operation == "APPLY" and j.lifecycle_state == "SUCCEEDED" and j.time_finished is not None],
            key=lambda j: j.time_finished,
        )
        if succeeded_apply_jobs:
            age = datetime.now(timezone.utc) - succeeded_apply_jobs[-1].time_finished
            if age < timedelta(minutes=cooldown_minutes):
                return response.Response(ctx, response_data=json.dumps({"status": "cooldown", "minutes_remaining": cooldown_minutes - int(age.total_seconds() / 60)}), headers={"Content-Type": "application/json"})

        node_values = []
        for inst in memory_instances:
            value = _latest_memory_value(monitoring_client, compartment_id, inst.id, window_minutes)
            if value is None:
                return response.Response(ctx, response_data=json.dumps({"status": "no-metric", "instance_id": inst.id}), headers={"Content-Type": "application/json"})
            node_values.append({"instance_id": inst.id, "value": value})

        if scale_rule == "all_nodes":
            failing = [n for n in node_values if n["value"] <= threshold]
            if failing:
                return response.Response(
                    ctx,
                    response_data=json.dumps({"status": "threshold-not-met", "rule": scale_rule, "failing_nodes": failing}),
                    headers={"Content-Type": "application/json"},
                )
        elif scale_rule == "any_node":
            passing = [n for n in node_values if n["value"] > threshold]
            if not passing:
                return response.Response(
                    ctx,
                    response_data=json.dumps({"status": "threshold-not-met", "rule": scale_rule, "node_values": node_values}),
                    headers={"Content-Type": "application/json"},
                )
        elif scale_rule == "average_nodes":
            avg = sum(n["value"] for n in node_values) / len(node_values)
            if avg <= threshold:
                return response.Response(
                    ctx,
                    response_data=json.dumps({"status": "threshold-not-met", "rule": scale_rule, "average": avg, "node_values": node_values}),
                    headers={"Content-Type": "application/json"},
                )
        else:
            return response.Response(
                ctx,
                response_data=json.dumps({"status": "invalid-rule", "rule": scale_rule}),
                headers={"Content-Type": "application/json"},
                status_code=400,
            )

        next_count = current_count + 1
        if dry_run:
            return response.Response(ctx, response_data=json.dumps({"status": "dry-run", "next_count": next_count}), headers={"Content-Type": "application/json"})

        job = _create_rm_apply_job(rm_client, stack_id, next_count)
        return response.Response(
            ctx,
            response_data=json.dumps({"status": "scale-triggered", "next_count": next_count, "job_id": job.id}),
            headers={"Content-Type": "application/json"},
        )
    except Exception as exc:
        _log(f"error: {exc}")
        return response.Response(ctx, response_data=json.dumps({"status": "error", "message": str(exc)}), headers={"Content-Type": "application/json"}, status_code=500)
