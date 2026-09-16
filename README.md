# Personal k3s Homelab Cluster - All-in-One Kubernetes Setup

This repository contains my complete **Infrastructure as Code (IaC)** setup for a lightweight, personal Kubernetes cluster using **k3s**.  
It runs on a single node on a VPS and hosts all my self-hosted services.

## Hosted Services

Currently running:

- **Immich** – Self-hosted Google Photos alternative
- **SonarQube** – Code quality & security analysis
- **Minecraft Server** (via Itzg Docker image)
- **Personal Website** using Astro Framework and accessible from TOR network
- **Cert-Manager** – Automatic SSL certificates
- **Envoy API Gateway** - Reverse proxy
- **Wireguard** - Fast and secure VPN
- **n8n** - Workflow automation platform
- And more to come…

### Personal website

Accessible from https://www.kouidri.fr or http://kouidri6bhboadbevagrvs52nmyvfhgafavqozvs6b756bzh3e4sd7qd.onion using [TOR browser](https://www.torproject.org)

## How to set up

Look `SERVER_CONFIG.md`

## Backups

`docs/backups/README.md` covers what is backed up, how to verify a backup
restores (`scripts/verify-restore.sh`), and how to restore for real.

## Making a change

`main` takes no direct pushes. The seven CI checks have to pass before anything merges,
and there are no bypass actors on the ruleset. That is deliberate: Flux syncs `main` every
minute while a CI run takes about fifty seconds, so a direct push would reach the cluster
at roughly the moment CI was deciding whether it should have. The pull request is what
turns CI from informative into preventive.

### The loop

```bash
# 1. branch
git switch -c <type>/<subject>              # fix/stalwart-probe, feat/alerting, docs/...

# 2. edit, then check the manifests still render and validate
scripts/validate-manifests.sh apps          # or infra, or any single path
scripts/validate-manifests.sh --server apps # also dry-runs against the live cluster

# 3. commit -- the pre-commit hook replays most of CI on the staged tree
git commit -m "<type>(<scope>): <subject>"

# 4. open the pull request and arm auto-merge
git push -u origin HEAD
gh pr create --fill
gh pr merge --auto --squash

# 5. after it merges, apply without waiting for the next sync
config-install/flux-reconcile.sh
```

Nothing needs watching between 4 and 5: GitHub merges as soon as the checks are green and
deletes the branch. Use `gh pr checks --watch` to follow along, or just come back later.

### What has to pass

| Check | What it does |
|---|---|
| Lint YAML | yamllint across the tree |
| Lint workflows | actionlint on `.github/workflows/` |
| Lint shell scripts | shellcheck, errors only |
| Validate Kubernetes manifests | `kustomize build` + kubeconform on every root |
| Verify secrets are SOPS-encrypted | every `*.enc.yaml` really is ciphertext |
| Scan for leaked secrets | gitleaks over the whole history, not just the tree |
| SonarQube Scan | analysis plus the quality gate |

The `pre-commit` hook runs most of them locally first, so a red CI on a green commit
usually means something the hook cannot see: SonarQube's quality gate, or a check that was
skipped with `SKIP_HOOKS=1`.

### When a check fails

Push another commit to the same branch. Auto-merge stays armed and fires by itself once
the checks go green -- no need to re-run `gh pr merge`.

There is no emergency route. An urgent fix takes the same path as everything else, which
costs about fifty seconds. Unblocking `main` faster than that means adding a bypass actor
to the ruleset on purpose, and removing it afterwards.

## Contributing

After cloning, install the git hooks once (git hooks are not versioned by design, so
`core.hooksPath` is pointed at the versioned `.githooks/` directory):

```bash
config-install/install-git-hooks.sh --install-tools
```

`--install-tools` also installs the linters (yamllint, kubeconform, gitleaks, actionlint,
shellcheck), pinned to the same versions CI uses. Drop the flag if you already have them.

The `pre-commit` hook then runs the CI checks on the staged tree before each commit:
yamllint, `kustomize build` + kubeconform on the touched roots, SOPS encryption checks,
a plaintext-`Secret` guard, actionlint, gitleaks and shellcheck. The `commit-msg` hook
enforces conventional commits. Bypass with `git commit --no-verify` when you must.