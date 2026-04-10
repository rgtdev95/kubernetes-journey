# Terraform Proxmox Provisioning Guide

This directory contains the Infrastructure-as-Code (Terraform) blueprint for physically provisioning the 6 bare-metal Virtual Machines on Proxmox VE 9.

### Prerequisites (WSL/Ubuntu)

1. Ensure Terraform is installed locally:
   ```bash
   sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
   wget -O- https://apt.releases.hashicorp.com/gpg | \
   gpg --dearmor | \
   sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
   https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
   sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt update
   sudo apt-get install terraform
   ```
2. You must have a **Debian 12 Cloud-Init Template** stored in Proxmox.
3. You need a **Proxmox API Token**.

---

## Configuration

Before executing Terraform, you must ensure your environment is authenticated against your Proxmox server.

Set your Proxmox provider variables in your environment (or write a `terraform.tfvars` file):

```bash
export PM_API_URL="https://192.168.1.xxx:8006/api2/json"
export PM_API_TOKEN_ID="root@pam!terraform"
export PM_API_TOKEN_SECRET="<your-secret-uuid>"
```

### Infrastructure Specs Defined in `main.tf`
This setup provisions fixed-IP clusters connected to `vmbr0` acting exclusively as Kubernetes nodes:

| Cluster Role | Count | CPU / RAM | Static IP (Gateway: 192.168.1.1) |
|---|---|---|---|
| central-hub | 2 | 2 Core / 4GB | 192.168.1.107, 192.168.1.102 |
| prod-cluster | 2 | 2 Core / 4GB | 192.168.1.103, 192.168.1.104 |
| dev-cluster | 2 | 2 Core / 4GB | 192.168.1.105, 192.168.1.106 |

*(Note: Cloud-Init inherently injects our primary AdGuard DNS server `192.168.1.108` and auto-configures the SSH keys for Ansible!)*

---

## Execution Guide

To stand up the servers from scratch:

**1. Initialize Terraform Plugins**
Downloads the Proxmox `bpg/proxmox` provider module.
```bash
terraform init
```

**2. Preview Changes**
Verifies the configuration and outputs the exact resources Terraform intends to create on the hypervisor.
```bash
terraform plan
```

**3. Apply Infrastructure**
Physically directs Proxmox to clone the templates, allocate the hard drives, spin up the VMs, and execute Cloud-Init IP configuration.
```bash
terraform apply
```

*(To tear down the entire environment and delete the VMs, run `terraform destroy`)*
