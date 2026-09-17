provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = data.vault_kv_secret_v2.proxmox.data["api_token"]
  insecure  = true # self-signed Proxmox cert; set false if using a trusted cert
}

module "vm" {
  source = "../../modules/proxmox-vm"

  vm_name         = var.vm_name
  template_vm_id  = var.template_vm_id
  node_name       = var.proxmox_node
  cpu_cores       = var.cpu_cores
  memory_mb       = var.memory_mb
  disk_size_gb    = var.disk_size_gb
  vm_ip           = var.vm_ip
  vm_id           = var.vm_id
  vm_gateway      = var.vm_gateway
  dns_server      = var.dns_server
  ansible_ssh_key = data.vault_kv_secret_v2.ansible.data["ssh_pubkey"]
  tags            = ["general", "managed"]
  vlan_id         = var.vlan_id
}

output "vm_ip" {
  value = module.vm.vm_ip
}

output "vm_name" {
  value = module.vm.vm_name
}

# Shows live resource usage so you can verify capacity before applying.
# Works on a single node and on clusters alike.
data "proxmox_virtual_environment_nodes" "all" {}

output "node_resources" {
  description = "Current resource usage per node"
  value = {
    for i, name in data.proxmox_virtual_environment_nodes.all.names : name => {
      cpu_usage_percent = floor(data.proxmox_virtual_environment_nodes.all.cpu_utilization[i] * 1000) / 10
      memory_used_gb    = floor(data.proxmox_virtual_environment_nodes.all.memory_used[i] / 107374182) / 10
      memory_total_gb   = floor(data.proxmox_virtual_environment_nodes.all.memory_available[i] / 107374182) / 10
    }
    if data.proxmox_virtual_environment_nodes.all.online[i]
  }
}
