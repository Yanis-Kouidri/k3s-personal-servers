#!/usr/bin/env bash
# Apply main right away instead of waiting for Flux's next sync (1 min for the source,
# 10 min for the Kustomizations).
set -euo pipefail

# Fetches the Git source once, and applies clusters/my-cluster: the Kustomization
# objects below may have changed themselves.
flux reconcile kustomization flux-system --with-source

# Then each layer in dependency order: infra depends on envoy and cert-manager, apps
# on infra. The source is already fresh, so no --with-source: it would fetch it again
# and re-apply flux-system each time.
for ks in envoy cert-manager infra apps; do
  flux reconcile kustomization "$ks"
done
