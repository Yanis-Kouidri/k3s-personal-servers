# Agent Guide — k3s Personal Servers

## What this repo is
GitOps repository for a **single-node K3s homelab** (Ubuntu 26.04 on an OVH VPS, 8 vCPU / 24 GB RAM).
FluxCD v2 reconciles the cluster from Git; all changes are **declarative YAML manifests**.

## Golden rules
- **Never** `kubectl apply` for permanent workloads. Write Git-tracked YAML and let Flux sync.
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

## No-op for agents
- No package.json / go.mod / Makefile / Taskfile — there is nothing to build or install locally.
- `sonar-project.properties` only configures the CI-side SonarQube scan exclusions (`clusters/**/flux-system/*`).
