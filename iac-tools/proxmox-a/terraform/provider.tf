terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.99"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_url
  api_token = var.proxmox_api_token
  insecure  = true   # set to false if you have a valid TLS cert

  ssh {
    agent    = false
    username = "root"
    password = var.proxmox_ssh_password
  }
}