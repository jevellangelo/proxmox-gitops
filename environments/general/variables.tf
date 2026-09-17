# environments/general/variables.tf

variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API endpoint"
  default     = "https://192.168.1.10:8006"
}

variable "proxmox_node" {
  type        = string
  description = "Proxmox node to deploy the VM on (e.g. pve)"
}

variable "template_vm_id" {
  type        = number
  description = "VM ID of the cloud-init template to clone"
}

variable "vm_name" {
  type = string
}

variable "vm_ip" {
  type        = string
  description = "Static IP with CIDR, e.g. 192.168.1.50/24"
}

variable "vm_gateway" {
  type    = string
  default = "192.168.1.1"
}

variable "dns_server" {
  type    = string
  default = "192.168.1.1"
}

variable "cpu_cores" {
  type    = number
  default = 2
}

variable "memory_mb" {
  type    = number
  default = 2048
}

variable "disk_size_gb" {
  type    = number
  default = 20
}

variable "vm_id" {
  type    = number
  default = 0
}

variable "vlan_id" {
  type    = number
  default = 0
}
