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