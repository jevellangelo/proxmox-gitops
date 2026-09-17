provider "vault" {
  address          = var.vault_addr
  skip_child_token = true
}

variable "vault_addr" {
  type    = string
  default = ""
}

data "vault_kv_secret_v2" "proxmox" {
  mount = "secret"
  name  = "proxmox"
}

data "vault_kv_secret_v2" "ansible" {
  mount = "secret"
  name  = "ansible"
}
