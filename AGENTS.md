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

## Standard change workflow

For every requested change that modifies cluster state (new workload, configuration change, bug fix, dependency update, etc.), agents **must** follow this workflow in order:

### 1. Understand the current state

1. Identify the owning application or infrastructure component.
2. Read the relevant manifests, Kustomization, HelmRelease, and documentation.
3. Check dependencies, namespace boundaries, and related resources (Gateway, HTTPRoute, Services, Secrets, ConfigMaps, etc.).
4. If the issue is reported as a failure or misbehavior, inspect:
   - `kubectl get` / `kubectl describe` for the affected resources
   - events and conditions on the resource
   - controller logs when relevant (Flux, cert-manager, Envoy Gateway, app pods)

Do not propose a fix until you can clearly state what is wrong and why.

### 2. Design the minimal fix

1. Make the smallest change that satisfies the request.
2. Preserve existing labels, selectors, and API versions unless a deliberate migration is requested.
3. Avoid changing unrelated files or sections.
4. For configuration changes, prefer editing existing fields over duplicating resources.

### 3. Apply the change locally

1. Edit the relevant YAML manifests in the repository.
2. If the change affects a Kustomization, verify that the path and overlays are correct.
3. Run `kustomize build` on the affected path to ensure it renders correctly.

### 4. Validate against the cluster (dry-run)

1. Run a server-side dry-run for the affected manifests, for example:
   ```bash
   kubectl apply --dry-run=server -f <path-to-manifests-or-kustomize-output>
   ```
2. Confirm that:
   - the dry-run succeeds
   - no unexpected resources are created, deleted, or replaced
   - no critical fields (selectors, PVCs, Service ports, Gateway references) are unintentionally modified

If the dry-run fails, fix the manifests before proceeding.

### 5. Inspect the Git diff

1. Run `git diff` and review all changed files.
2. Verify that:
   - no plaintext secret, private key, token, or password is present
   - no unrelated files are modified
   - no sensitive data is leaked in comments or metadata
3. Ensure the diff matches the intended change.

### 6. Commit, push, and reconcile

Only proceed with these steps when the user has explicitly approved the change.

1. Commit with a clear conventional commit message, for example:
   - `fix(immich): correct database secret reference`
   - `feat(n8n): add resource limits and probes`
   - `chore(flux): pin cert-manager to v1.16.2`
2. Push the commit to the main branch.
3. Run the reconciliation script from the repository root:
   ```bash
   ./config-install/flux-reconcile.sh
   ```
4. Treat this as a cluster-mutating operation.

### 7. Verify and test

1. Inspect Flux status for the affected Kustomizations / HelmReleases:
   ```bash
   flux get kustomizations -A
   flux get helmreleases -A
   ```
2. Check that the targeted resources are `Ready` and without error conditions.
3. Test the behavior that was reported as broken (HTTP endpoint, application feature, probe, etc.).
4. If reconciliation fails or the issue persists:
   - inspect events and controller logs
   - do not repeatedly retry blindly
   - report the observed state and propose the next corrective step


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
- SOPS uses the age recipient configured in `.sops.yaml`.
- Never expose or commit the age private key.
- Before modifying encrypted files, inspect `.sops.yaml` and preserve the existing SOPS metadata.
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
2. IPv6 is native (dual-stack in `config.yaml`).
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