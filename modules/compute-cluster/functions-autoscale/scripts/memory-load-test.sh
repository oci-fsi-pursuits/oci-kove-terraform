#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-start}"

REGION="${REGION:-eu-frankfurt-1}"
COMPARTMENT_OCID="${COMPARTMENT_OCID:-}"
SSH_USER="${SSH_USER:-opc}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_rsa}"
SSH_OPTS="${SSH_OPTS:--o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=8}"

TARGET_PERCENT="${TARGET_PERCENT:-90}"
VM_WORKERS="${VM_WORKERS:-4}"
DURATION="${DURATION:-20m}"
INSTALL_STRESS_NG="${INSTALL_STRESS_NG:-true}"

if [[ -z "${COMPARTMENT_OCID}" ]]; then
  echo "COMPARTMENT_OCID is required."
  echo "Example: export COMPARTMENT_OCID='ocid1.compartment.oc1..aaaa...'"
  exit 1
fi

if ! command -v oci >/dev/null 2>&1; then
  echo "OCI CLI is required in PATH."
  exit 1
fi

if [[ ! -f "${SSH_KEY_PATH}" ]]; then
  echo "SSH key not found: ${SSH_KEY_PATH}"
  exit 1
fi

if ! [[ "${TARGET_PERCENT}" =~ ^[0-9]+$ ]] || (( TARGET_PERCENT < 1 || TARGET_PERCENT > 98 )); then
  echo "TARGET_PERCENT must be an integer between 1 and 98."
  exit 1
fi

if ! [[ "${VM_WORKERS}" =~ ^[0-9]+$ ]] || (( VM_WORKERS < 1 || VM_WORKERS > 64 )); then
  echo "VM_WORKERS must be an integer between 1 and 64."
  exit 1
fi

PER_WORKER_PERCENT=$(( TARGET_PERCENT / VM_WORKERS ))
if (( PER_WORKER_PERCENT < 1 )); then
  PER_WORKER_PERCENT=1
fi

echo "Discovering memory nodes in ${REGION}..."
INSTANCE_IDS="$(oci --region "${REGION}" compute instance list \
  --compartment-id "${COMPARTMENT_OCID}" \
  --lifecycle-state RUNNING \
  --all \
  --query "data[?\"freeform-tags\".node_pool=='rdma-memory' && \"freeform-tags\".node_role=='memory'].id" \
  --raw-output)"

if [[ -z "${INSTANCE_IDS}" ]]; then
  echo "No running memory nodes found (tags node_pool=rdma-memory and node_role=memory)."
  exit 1
fi

run_ssh() {
  local ip="$1"
  local remote_cmd="$2"
  # shellcheck disable=SC2086
  ssh -i "${SSH_KEY_PATH}" ${SSH_OPTS} "${SSH_USER}@${ip}" "${remote_cmd}"
}

for IID in ${INSTANCE_IDS}; do
  IP="$(oci --region "${REGION}" compute instance list-vnics \
    --instance-id "${IID}" \
    --query "data[0].\"private-ip\"" \
    --raw-output)"

  if [[ -z "${IP}" || "${IP}" == "null" ]]; then
    echo "[WARN] Skipping ${IID}: could not resolve private IP."
    continue
  fi

  echo "[$IP] action=${ACTION}"

  case "${ACTION}" in
    start)
      if [[ "${INSTALL_STRESS_NG}" == "true" ]]; then
        run_ssh "${IP}" "if ! command -v stress-ng >/dev/null 2>&1; then if command -v dnf >/dev/null 2>&1; then sudo dnf -y install stress-ng; else sudo yum -y install stress-ng; fi; fi"
      fi
      run_ssh "${IP}" "sudo pkill -f 'stress-ng --vm' || true"
      run_ssh "${IP}" "nohup sudo stress-ng --vm ${VM_WORKERS} --vm-bytes ${PER_WORKER_PERCENT}% --vm-populate --vm-keep --timeout ${DURATION} --metrics-brief > /tmp/rdma-memory-load-test.log 2>&1 < /dev/null &"
      run_ssh "${IP}" "sleep 2; pgrep -a stress-ng || true"
      ;;
    status)
      run_ssh "${IP}" "pgrep -a stress-ng || echo 'stress-ng not running'; free -h"
      ;;
    stop)
      run_ssh "${IP}" "sudo pkill -f 'stress-ng --vm' || true; pgrep -a stress-ng || echo 'stopped'"
      ;;
    *)
      echo "Unsupported action: ${ACTION}"
      echo "Usage: $(basename "$0") [start|status|stop]"
      exit 1
      ;;
  esac
done

if [[ "${ACTION}" == "start" ]]; then
  echo "Started load across memory nodes."
  echo "Settings: TARGET_PERCENT=${TARGET_PERCENT}, VM_WORKERS=${VM_WORKERS}, PER_WORKER_PERCENT=${PER_WORKER_PERCENT}, DURATION=${DURATION}"
  echo "Use: $(basename "$0") status"
  echo "Logs per node: /tmp/rdma-memory-load-test.log"
fi
