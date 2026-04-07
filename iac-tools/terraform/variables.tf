variable "proxmox_url" {
  type        = string
  description = "Proxmox API URL e.g. https://192.168.1.100:8006"
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

variable "proxmox_ssh_password" {
  type      = string
  sensitive = true
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node name e.g. pve"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to your SSH public key"
  default     = "~/.ssh/id_ed25519.pub"
}