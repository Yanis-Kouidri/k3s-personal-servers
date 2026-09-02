# AGENTS.md

## Stack

k3s single node on an Ubuntu 26.04 VPS with 8 vCPU and 24GB of RAM
Traefik is disabled. All HTTP traffic is handled by Envoy API Gateway
Non-HTTP services use a k3s's built-in ServiceLB to expose a LoadBalancer Service on the node's IP (using the service's port, e.g. port 25565 for minecraft-server)
HTTP certificates are handled with cert-manager
GitOps is handled by Flux CD
Reflector is used to replicate secrets when needed
The cluster uses Dual-stack IP (IPv4 and IPv6)
Kubernetes secrets are encrypted with SOPS and age.

## Structure

- `apps/`: Contains yaml manifests for user applications of the cluster such as n8n, mail, crowdsec, immich, authentik, minecraft-server, personal-website-v2, sonarqube and wireguard-vpn. One folder per app
- `backups/`: Bash scripts for backups
- `clusters/`: Flux manifests
- `config-install/`: Install or maintenance scripts
- `docs/`: Docs
- `infra/`: Contains yaml manifests for infra applications of the cluster such as cert-manager, envoy and reflector. One app per folder
- `.sops.yaml`: Contains rules for secrets encryption. To encrypt a plaintext secret use `sops -e secret.enc.yaml`, it will output an encrypted version.

## Workflow

To fix a problem or create something new, follow this workflow:

- Read the files, inspect the logs and the Kubernetes resources
- Modify existing files and/or create new files to complete what I ask
- Check that the new or modified files are still correct and followed by FluxCD with the command : `kustomize build <path> | kubectl apply --dry-run=server -f -`
- If it's correct, commit with a conventional commit message, push on the branch main and run `config-install/flux-reconcile.sh` to apply the modification
- Check that the change was applied correctly

## Guardrails

- Never commit a decrypted secret. Use sops to encrypt it.
- Do not modify `.sops.yaml`.
- Do not manually edit `clusters/**/gotk-components.yaml` (managed by the Flux self-update workflow)