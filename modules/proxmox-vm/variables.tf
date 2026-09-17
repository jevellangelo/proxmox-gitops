variable "vm_name" {
  type = string
}

variable "template_vm_id" {
  type        = number
  description = "VM ID of the cloud-init template to clone (must be on the same node)"
}

variable "node_name" {
  type        = string
  description = "Proxmox node to deploy the VM on"

  validation {
    condition     = length(var.node_name) > 0
    error_message = "node_name cannot be empty. Set the proxmox_node pipeline input (e.g. pve)."
  }
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

variable "datastore_id" {
  type        = string
  description = "Storage pool for the VM root disk"
  default     = "local-lvm"
}

variable "vm_ip" {
  type        = string
  description = "Static IP with CIDR, e.g. 192.168.1.50/24"
}

variable "vm_gateway" {
  type        = string
  description = "Default gateway for the VM subnet"
}

variable "dns_server" {
  type    = string
  default = "192.168.1.1"
}

variable "ansible_ssh_key" {
  type        = string
  description = "SSH public key injected via cloud-init for Ansible access"
}

variable "tags" {
  type    = list(string)
  default = []
}

variable "vm_id" {
  type        = number
  description = "VM ID for the new VM. 0 = let Proxmox auto-assign."
  default     = 0
}

variable "vlan_id" {
  type        = number
  description = "VLAN tag for the network interface. 0 = untagged."
  default     = 0
}

variable "cloudinit_datastore_id" {
  type        = string
  description = "Storage pool for the cloud-init drive"
  default     = "local-lvm"
}
