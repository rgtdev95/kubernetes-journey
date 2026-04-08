locals {
  gateway = "192.168.1.1"

  vms = {
    "central-hub-cp" = {
      cores    = 2
      memory   = 6144
      disk_gb  = 20
      ip       = "192.168.1.107/24"
      username = "k8sadmin"
    }
    "central-hub-worker" = {
      cores    = 2
      memory   = 6144
      disk_gb  = 20
      ip       = "192.168.1.102/24"
      username = "k8sadmin"
    }
    "prod-cluster-cp" = {
      cores    = 2
      memory   = 4096
      disk_gb  = 20
      ip       = "192.168.1.103/24"
      username = "k8sadmin"
    }
    "prod-cluster-worker" = {
      cores    = 2
      memory   = 4096
      disk_gb  = 20
      ip       = "192.168.1.104/24"
      username = "k8sadmin"
    }
    "dev-cluster-cp" = {
      cores    = 2
      memory   = 4096
      disk_gb  = 20
      ip       = "192.168.1.105/24"
      username = "k8sadmin"
    }
    "dev-cluster-worker" = {
      cores    = 2
      memory   = 4096
      disk_gb  = 20
      ip       = "192.168.1.106/24"
      username = "k8sadmin"
    }
  }
}

resource "proxmox_virtual_environment_vm" "vms" {
  for_each  = local.vms
  name      = each.key
  node_name = var.proxmox_node

  clone {
    vm_id = 9000
    full  = true
  }

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = each.value.disk_gb
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  initialization {
    dns {
      servers = ["192.168.1.108"]
    }

    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = local.gateway
      }
    }

    user_account {
      username = each.value.username
      keys     = [file(var.ssh_public_key_path)]
    }
  }
}

output "vm_ip_addresses" {
  description = "IP addresses of all provisioned VMs"
  value = {
    for name, vm in proxmox_virtual_environment_vm.vms :
    name => vm.ipv4_addresses
  }
}