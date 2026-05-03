# Offline RPM install guide for RHEL 8.10

Use this guide to configure Terraform/cloud-init to install required RPMs from the prebuilt RHEL 8.10 offline RPM repository tarball.

## Seed packages

RDMA/cloud-init bootstrap:

```text
python3
curl
rdma-core
libibverbs-utils
infiniband-diags
librdmacm-utils
```

MC KVM host bootstrap:

```text
python3
qemu-kvm
libvirt-daemon-kvm
libvirt
libvirt-client
virt-install
qemu-img
nftables
tar
```

## Object Storage links

RPM repository tarball:

```text
https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/N2QPxVlF6H9Jnytj_XY7kp7Ke2nQMwkYU9v5t8ZfMimvonopG3KuZChZQxJAOlfn/n/oraclejamescalise/b/Kove-rpms/o/kove-rhel8.10-offline-rpms.tar.gz
```

SHA256 checksum:

```text
https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/ePaXyledsRSd1DbSOT95_1MnPmih2aOOmMgG33bkZGnV9i107yJDALzZtQY6-6cJ/n/oraclejamescalise/b/Kove-rpms/o/kove-rhel8.10-offline-rpms.tar.gz.sha256
```

## Terraform variables

Add the tarball URL to your `.tfvars` file:

```hcl
offline_repo_tarball_url = "https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/N2QPxVlF6H9Jnytj_XY7kp7Ke2nQMwkYU9v5t8ZfMimvonopG3KuZChZQxJAOlfn/n/oraclejamescalise/b/Kove-rpms/o/kove-rhel8.10-offline-rpms.tar.gz"

mc_offline_repo_tarball_url = "https://objectstorage.eu-frankfurt-1.oraclecloud.com/p/N2QPxVlF6H9Jnytj_XY7kp7Ke2nQMwkYU9v5t8ZfMimvonopG3KuZChZQxJAOlfn/n/oraclejamescalise/b/Kove-rpms/o/kove-rhel8.10-offline-rpms.tar.gz"
```

Download the `.sha256` object and copy the checksum value into the same `.tfvars` file:

```hcl
offline_repo_tarball_sha256 = "REPLACE_WITH_SHA256_VALUE"

mc_offline_repo_tarball_sha256 = "REPLACE_WITH_SHA256_VALUE"
```

Cloud-init downloads the tarball, verifies the checksum when provided, extracts the RPM repository, writes a local `file://` yum repo, and installs only from that local repo.
