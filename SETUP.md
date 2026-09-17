# Setup

One-time configuration for Proxmox, Vault, and GitLab. Replace placeholder
values (`192.168.1.x`, `vault.example.com`, `<your-gitlab-username>`) with
your own.

## 1. Proxmox — cloud-init template

On the Proxmox node (creates template VM ID `9000`):

```bash
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

qm create 9000 --name ubuntu-2404-cloud-init --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-single --agent enabled=1
qm importdisk 9000 noble-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsi0 local-lvm:vm-9000-disk-0,discard=on,iothread=1
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot order=scsi0
qm set 9000 --serial0 socket --vga serial0
qm template 9000
```

## 2. Proxmox — restricted API token for Terraform

```bash
pveum role add TerraformProvisioner -privs "VM.Allocate VM.Clone \
  VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk \
  VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options \
  VM.PowerMgmt VM.Audit Datastore.AllocateSpace Datastore.AllocateTemplate \
  Datastore.Audit SDN.Use Sys.Audit"

pveum user add terraform@pam
pveum aclmod / -user terraform@pam -role TerraformProvisioner
pveum user token add terraform@pam gitops -privsep 0
```

Save the token output — it goes into Vault next as
`terraform@pam!gitops=<uuid>`.

## 3. Vault — secrets

Assumes KV v2 mounted at `secret/` and an SSH keypair generated for Ansible
(`ssh-keygen -t ed25519 -f ansible_key -C ansible`).

```bash
vault kv put secret/proxmox \
  api_token="terraform@pam!gitops=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

vault kv put secret/ansible \
  ssh_pubkey="$(cat ansible_key.pub)" \
  ssh_private_key="$(cat ansible_key)"

vault kv put secret/users/admin    ssh_pubkey="ssh-ed25519 AAAA... admin"
vault kv put secret/users/deployer ssh_pubkey="ssh-ed25519 AAAA... deployer"
```

## 4. Vault — policies

```bash
vault policy write terraform-policy - << 'EOF'
path "secret/data/proxmox" { capabilities = ["read"] }
path "secret/data/ansible" { capabilities = ["read"] }
EOF

vault policy write ansible-policy - << 'EOF'
path "secret/data/ansible"  { capabilities = ["read"] }
path "secret/data/users/*"  { capabilities = ["read"] }
EOF
```

## 5. Vault — JWT auth for GitLab CI

This is what lets CI jobs authenticate without any stored token. The
`bound_claims` lock token issuance to **your project on your main branch** —
a valid GitLab JWT from any other project or branch is rejected.

```bash
vault auth enable jwt

vault write auth/jwt/config \
  jwks_url="https://gitlab.com/-/jwks" \
  bound_issuer="https://gitlab.com"

vault write auth/jwt/role/gitlab-terraform \
  role_type="jwt" \
  user_claim="sub" \
  bound_claims_type="glob" \
  bound_claims='{"project_path":"<your-gitlab-username>/proxmox-gitops","ref":"main","ref_type":"branch"}' \
  policies="terraform-policy" \
  ttl="1h"

vault write auth/jwt/role/gitlab-ansible \
  role_type="jwt" \
  user_claim="sub" \
  bound_claims_type="glob" \
  bound_claims='{"project_path":"<your-gitlab-username>/proxmox-gitops","ref":"main","ref_type":"branch"}' \
  policies="ansible-policy" \
  ttl="1h"
```

If self-hosting GitLab, replace `gitlab.com` with your instance URL in both
the JWKS URL and bound_issuer.

## 6. GitLab — runner

Register a runner on a host that can reach both the Proxmox API and Vault:

```bash
sudo gitlab-runner register
# executor: docker
# default image: alpine:latest
# tags: proxmox
```

In `/etc/gitlab-runner/config.toml`:

```toml
concurrent = 3            # lets the validate jobs run in parallel

[[runners]]
  [runners.docker]
    privileged = true     # required only for the docker:dind build jobs
```

Note: if you set `network_mode = "host"` (e.g. so job containers can reach
LAN IPs directly), the dind build jobs will conflict on ports when run
concurrently — build the images locally instead (step 8).

## 7. GitLab — CI/CD variables

Settings ▸ CI/CD ▸ Variables:

| Variable | Value | Masked |
|---|---|---|
| `VAULT_ADDR` | `https://vault.example.com` | no |
| `SLACK_WEBHOOK_URL` | approvals-channel webhook | yes |
| `SLACK_STATUS_WEBHOOK_URL` | status-channel webhook | yes |

## 8. CI images (first build)

The pipeline's jobs run on two custom images. Build them once (afterwards the
`build:` jobs rebuild automatically when a Dockerfile changes on push):

```bash
docker login registry.gitlab.com   # username + PAT with read/write_registry

docker build -t registry.gitlab.com/<your-gitlab-username>/proxmox-gitops/terraform:latest docker/terraform/
docker push  registry.gitlab.com/<your-gitlab-username>/proxmox-gitops/terraform:latest

docker build -t registry.gitlab.com/<your-gitlab-username>/proxmox-gitops/ansible:latest docker/ansible/
docker push  registry.gitlab.com/<your-gitlab-username>/proxmox-gitops/ansible:latest
```

## 9. First run

```bash
git push origin main          # validate stage should pass
```

Then CI/CD ▸ Pipelines ▸ Run pipeline ▸ fill in `vm_name`, `vm_ip`, leave the
rest on defaults ▸ approve `tf:apply` when the Slack message arrives.
