# proxmox-gitops

A GitOps pipeline for provisioning and configuring VMs on Proxmox — fill out a
form in GitLab, review the plan in Slack, click approve, and get a fully
configured Ubuntu VM with Docker, users, and SSH keys. Destroy works the same
way, with an approval gate.

All secrets live in HashiCorp Vault. Nothing sensitive is stored in GitLab —
CI jobs authenticate to Vault dynamically using GitLab's JWT identity and
receive short-lived, scoped tokens.

> This repository accompanies a blog series walking through the full build.
> Links to each part will be added here as they are published.

## How it works

```
You (GitLab web UI form)
    |
    v
GitLab CI pipeline
    |
    |-- validate   terraform validate / fmt, ansible-lint   (every push)
    |-- plan       terraform plan -> Slack approval message
    |-- apply      terraform apply (manual gate) -> VM created on Proxmox
    |-- configure  ansible -> Docker, qemu-guest-agent, users, SSH keys
    |
    v
Running, configured VM   (Slack: "VM Ready")
```

Secrets flow:

```
GitLab signs a per-job JWT  ->  Vault verifies it (JWKS + bound_claims)
                            ->  Vault issues a 1-hour scoped token
                            ->  job reads only the secrets its policy allows
```

## Stack

| Component | Role |
|---|---|
| Proxmox VE (single node) | Hypervisor |
| HashiCorp Vault | Secrets (Proxmox API token, SSH keys) |
| Terraform (`bpg/proxmox` provider) | VM provisioning, state in GitLab |
| Ansible | VM configuration |
| GitLab CI + Runner (Docker executor) | Orchestration |
| Slack (incoming webhooks) | Approvals and status notifications |

## Repository layout

```
.gitlab-ci.yml              Pipeline definition
docker/                     Custom CI images (terraform + curl, ansible + hvac)
environments/general/       Terraform root module (providers, backend, inputs)
modules/proxmox-vm/         Reusable VM module
ansible/                    Playbook + roles: base, docker, qemu_guest_agent, users
```

## Prerequisites

- A Proxmox node with an Ubuntu cloud-init template (default expected ID: `9000`)
- A Vault server reachable from your runner (KV v2 mounted at `secret/`)
- A GitLab project with a self-hosted runner (Docker executor, tag `proxmox`)
- Two Slack incoming webhooks (approvals channel + status channel) — optional
  but the pipeline posts to them

Full setup commands (Proxmox API token, Vault policies, JWT auth, runner
notes) are in [SETUP.md](SETUP.md).

## Quick start

1. Fork/clone this repo into your own GitLab project.
2. Complete [SETUP.md](SETUP.md) — Proxmox token, Vault secrets/policies/JWT
   roles (the JWT role's `bound_claims` must point at **your** project path).
3. Set CI/CD variables: `VAULT_ADDR`, `SLACK_WEBHOOK_URL`,
   `SLACK_STATUS_WEBHOOK_URL`.
4. Build and push the two CI images once (see SETUP.md), or change a
   Dockerfile and push to trigger the build jobs.
5. Push to `main` — the validate stage should pass.
6. CI/CD ▸ Pipelines ▸ **Run pipeline** ▸ fill in the form ▸ approve via the
   Slack link ▸ watch your VM appear.

## Pipeline inputs

| Input | Default | Notes |
|---|---|---|
| `action` | `apply` | `apply` creates, `destroy` removes |
| `vm_name` | `test-vm-` | Hostname + Proxmox display name |
| `vm_ip` | `192.168.1.x/24` | Static IP with CIDR |
| `vm_gateway` | `192.168.1.1` | Change when targeting another subnet/VLAN |
| `template_vm_id` | `9000` | Cloud-init template to clone |
| `proxmox_node` | `pve` | Target node |
| `vm_id` | `0` | `0` = Proxmox auto-assigns |
| `vlan_id` | `0` | `0` = untagged |

## Notes & defaults

- Storage defaults to `local-lvm` for both the VM disk and the cloud-init
  drive — the out-of-the-box layout on a single-node install. Override
  `datastore_id` / `cloudinit_datastore_id` for Ceph, ZFS, etc.
- The VM is created with `scsi_hardware = "virtio-scsi-single"`, iothread,
  and the QEMU guest agent enabled; the `qemu_guest_agent` role inside the
  VM depends on that agent flag.
- Managed users are defined in `ansible/roles/users/vars/main.yml`. Each
  user's public key must exist in Vault at `secret/users/<name>` **and** the
  name must be added to the fetch list in `.gitlab-ci.yml`
  (`ansible:configure` before_script).
- `terraform destroy` re-supplies the same inputs you used at apply time, so
  use identical values when destroying.

## License

MIT — see [LICENSE](LICENSE).
