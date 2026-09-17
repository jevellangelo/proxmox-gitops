resource "proxmox_virtual_environment_vm" "vm" {
  name          = var.vm_name
  node_name     = var.node_name
  vm_id         = var.vm_id > 0 ? var.vm_id : null
  tags          = var.tags
  scsi_hardware = "virtio-scsi-single"

  agent {
    enabled = true
  }

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  cpu {
    cores = var.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.memory_mb
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = var.vlan_id > 0 ? var.vlan_id : null
  }

  disk {
    datastore_id = var.datastore_id
    interface    = "scsi0"
    size         = var.disk_size_gb
    discard      = "on"
    iothread     = true
    file_format  = "raw"
  }

  initialization {
    datastore_id = var.cloudinit_datastore_id
    ip_config {
      ipv4 {
        address = var.vm_ip
        gateway = var.vm_gateway
      }
    }
    dns {
      servers = [var.dns_server]
    }
    user_account {
      username = "ubuntu"
      keys     = [var.ansible_ssh_key]
    }
  }

  lifecycle {
    ignore_changes = [
      # Prevents Terraform re-cloning if VM is modified outside Terraform
      clone,
      initialization,
    ]
  }
}
