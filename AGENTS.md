# Agent Guide — k3s Personal Servers

## What this repo is
GitOps repository for a **single-node K3s homelab** (Ubuntu 26.04 on an OVH VPS, 8 vCPU / 24 GB RAM).
FluxCD v2 reconciles the cluster from Git; all changes are **declarative YAML manifests**.

## Golden rules
- **Never** `kubectl apply` for permanent workloads. Write Git-tracked YAML, commit with a proper and clear commit message, push and finally run `config-install/flux-reconcile.sh` to apply modification and observe result.
- Secrets are encrypted with **SOPS + age**. Files matching `.*\.enc\.yaml$` are encrypted per `.sops.yaml`.
  - Re-encrypt after editing: `sops --encrypt --age <pub> file.yaml > file.enc.yaml`
  - Decryption secret `sops-age` (age key) must exist in the `flux-system` namespace (see `SERVER_CONFIG.md`).
- Traefik **is disabled** (`config-install/config.yaml`). HTTP routing uses the **Envoy API Gateway** (Gateway API).
- Envoy handles **HTTP/HTTPS only**. All non-HTTP services (Minecraft on `25565`, Wireguard VPN, mail/Stalwart, etc.) **bypass** Envoy via `Service type: LoadBalancer`.

## Flux dependency order (matters on reconcile)
`cert-manager` → `envoy` → `infra` → `apps`

Reconcile in that order via `config-install/flux-reconcile.sh`. New infra components should declare `dependsOn` correctly.

## Directory layout
| Path | Responsibility |
|------|---------------|
| `clusters/my-cluster/` | Flux entrypoint — `kustomization.yaml` + Kustomization CRs (cert-manager, envoy, infra, apps) |
| `apps/` | Application manifests (one Kustomization per app) |
| `infra/` | Cluster infra: cert-manager, networking/envoy-gateway, reflector |
| `config-install/` | One-time **server bootstrap** (k3s config, sshd hardening, dotfiles, flux-reconcile.sh) — not cluster workloads |
| `backups/` | Host-level backup shell scripts (`.sh` ignored by Sourcegraph; encrypted files skipped by Renovate) |
| `docs/` | Operational notes (e.g. FluxCD bootstrap/reconcile) |

## SOPS / age
- `.sops.yaml` uses the age public key `age1kyhazfmr49eddkxfws9apdlauaevqsktfhfhyxdhkxhwdg03qszs7c337j`.
- Encrypted file example: `apps/crowdsec/secrets.enc.yaml`.
- Renovate **ignores** `**/*.enc.yaml` — no dependency upgrades will be proposed for them.

## CI
- GitHub Actions runs a **SonarQube scan** on push/PR (`build.yml`). No unit tests, linting, or build steps exist.
- `update-flux.yml` auto-PRs on Mondays when Flux components drift (`gotk-components.yaml`).

## Renovate policy
- Pin/digest updates: auto-merge.
- Patch: auto-merge after **3 days**.
- Minor: auto-merge after **5 days**.
- Major: **no auto-merge** — manual review required.
- `gotk-components.yaml` and `**/*.enc.yaml` are ignored.

## K3s bootstrap (fresh VPS)
1. `SERVER_CONFIG.md` walks the full process. Key order:
   - SSH hardening → hostname/timezone → install k3s (with `config-install/config.yaml`)
   - Configure kubeconfig (`KUBECONFIG` export in `~/.bashrc`)
   - Install FluxCD + CLI (`docs/flux-cd/README.md`)
   - Create `sops-age` secret, then `flux bootstrap`
2. IPv6 is native (dual-stack in `config.yaml`). Test with `curl -6`.
3. Firewall lives at the **host/provider** level (OVH) — do not run `ufw` inside k3s.

## Exposed Services (Network topology)

### HTTP/HTTPS — via Envoy Gateway API (ports 80/443)
| Hostname | Service | Namespace | Backend port | Notes |
|---|---|---|---|---|
| `www.kouidri.fr` | personal-website-v2 | personal-website-v2 | 80 | Main website |
| `kouidri.fr` | redirect → www.kouidri.fr | personal-website-v2 | — | 301 redirect |
| `kouidri6bhboadbevagrvs52nmyvfhgafavqozvs6b756bzh3e4sd7qd.onion` | personal-website-v2 | personal-website-v2 | 80 | Tor hidden service (HTTP only) |
| `n8n.kouidri.fr` | n8n | n8n | 5678 | Workflow automation |
| `webmail.kouidri.fr` | bulwark (webmail) | mail | 3000 | Roundcube-like UI |
| `sonarqube.kouidri.fr` | sonarqube | sonarqube | 9000 | Code quality (via Helm httproute) |
| `kouidri.me`, `www.kouidri.me` | redirect → kouidri.fr | envoy-gateway-system | — | 301 redirect |

**TLS**: certificate managed by cert-manager (`kouidri-fr-tls` in `envoy-gateway-system`). HTTP → HTTPS forced globally.

### Non-HTTP — Direct LoadBalancer (bypass Envoy)
| Service | Port(s) | Protocol | Namespace | K8s Service |
|---|---|---|---|---|
| Minecraft | 25565 | TCP | minecraft | `minecraft-service` |
| WireGuard VPN | 51820 | UDP | wireguard | `wireguard-svc` |
| Stalwart Mail (SMTP) | 25 | TCP | mail | `stalwart-mail` |
| Stalwart Mail (Submissions) | 465 | TCP | mail | `stalwart-mail` |
| Stalwart Mail (Submission) | 587 | TCP | mail | `stalwart-mail` |
| Stalwart Mail (IMAPS) | 993 | TCP | mail | `stalwart-mail` |

> **OVH Firewall**: open only these ports at provider level. No `ufw` inside k3s.

### Cluster applications and servicies
- **cert-manager**: certificate management (Let's Encrypt)
- **Envoy Gateway**: ingress controller (dual-stack IPv4/IPv6)
- **FluxCD**: source/helm/kustomize/notification controllers
- **Reflector**: cross-namespace secret/configmap replication
- **Tor daemon**: hidden service for `.onion`
- **CrowdSec**: LAPI + agent (intrusion detection)
- **Immich**: Self-hosted Google Photos alternative
- **Minecraft Server**: Itzg-based Minecraft server
- **Personal website**: Astro-based website, also accessible through Tor
- **WireGuard**: Fast and secure VPN
- **n8n**: Workflow automation platform
- **SonarQube**: Static code quality and security analysis
- **Bulwark**: Webmail interface, exposed at `webmail.kouidri.fr`
- **Stalwart Mail**: Mail server providing SMTP, submission, and IMAPS services

## No-op for agents
- No package.json / go.mod / Makefile / Taskfile — there is nothing to build or install locally.
- `sonar-project.properties` only configures the CI-side SonarQube scan exclusions (`clusters/**/flux-system/*`).