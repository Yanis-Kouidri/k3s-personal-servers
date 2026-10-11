#!/usr/bin/env bash
# Validate rendered Kubernetes manifests: kustomize build + kubeconform (+ optional server dry-run).
#
# Usage:
#   scripts/validate-manifests.sh [--server] [--root DIR] [--kubeconform-optional] [path...]
#
#   path...                kustomization directories to validate (default: apps infra clusters/my-cluster)
#   --server               additionally run `kubectl apply --dry-run=server` against the live cluster
#   --root DIR             validate the tree in DIR instead of this repository (the pre-commit
#                          hook passes its snapshot of the index); not combinable with --server
#   --kubeconform-optional skip schema validation instead of failing when kubeconform is missing
#
# The single implementation of this check: CI (.github/workflows/build.yml) and the
# pre-commit hook both call it, so the kubeconform flags cannot drift between them.
#
# Why not plain `kustomize build <path> | kubectl apply --dry-run=server -f -`:
# Secrets live in git SOPS-encrypted, so the rendered stream carries a `sops:` metadata
# block plus ENC[...] values. The API server rejects every one of them with
# `strict decoding error: unknown field "sops"` and echoes the full ciphertext back,
# which buries any real error in thousands of lines. Decrypting them is Flux's job at
# apply time; their structure is verified by scripts/check-sops-encryption.sh instead.
# So Secrets are skipped here, and everything else is validated.
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; DIM=$'\033[2m'; OFF=$'\033[0m'
else
  BOLD=; RED=; GREEN=; DIM=; OFF=
fi

server=0
root=
kubeconform_optional=0
paths=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --server) server=1 ;;
    --root) root=${2:?--root needs a directory}; shift ;;
    --kubeconform-optional) kubeconform_optional=1 ;;
    -h|--help) sed -n '2,23p' "$0" | sed 's/^# \?//'; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) paths+=("${1%/}") ;;
  esac
  shift
done
[[ ${#paths[@]} -eq 0 ]] && paths=(apps infra clusters/my-cluster)

if [[ -n $root ]]; then
  # --server compares against the live cluster and greps the repository for node
  # addresses: it means "this checkout", never an arbitrary tree.
  [[ $server -eq 0 ]] || { echo "--root and --server cannot be combined" >&2; exit 2; }
  cd "$root"
else
  cd "$(git rev-parse --show-toplevel)"
fi

command -v kustomize >/dev/null 2>&1 || {
  echo "${RED}kustomize is not installed — config-install/install-git-hooks.sh --install-tools${OFF}" >&2
  exit 1
}
have_kubeconform=1
if ! command -v kubeconform >/dev/null 2>&1; then
  if [[ $kubeconform_optional -eq 0 ]]; then
    echo "${RED}kubeconform is not installed — config-install/install-git-hooks.sh --install-tools${OFF}" >&2
    exit 1
  fi
  have_kubeconform=0
  echo "${DIM}kubeconform not installed, schema validation skipped${OFF}"
fi

# Drops every `kind: Secret` document from a rendered stream. Parsing the YAML rather
# than grepping so a `kind: Secret` string nested in an RBAC rule or a comment cannot
# silently remove the wrong document.
strip_secrets() {
  python3 -c '
import sys, yaml
docs = [d for d in yaml.safe_load_all(sys.stdin) if d and d.get("kind") != "Secret"]
yaml.safe_dump_all(docs, sys.stdout)
'
}

failures=()
for path in "${paths[@]}"; do
  echo "${BOLD}==> $path${OFF}"

  # 1. the kustomization graph itself (encrypted Secrets are fine here: kustomize treats
  #    them as opaque resources and never needs to decrypt them)
  if ! build=$(kustomize build "$path" 2>&1); then
    echo "${RED}  ✗ kustomize build${OFF}"
    printf '%s\n' "$build" | sed 's/^/      /'
    failures+=("kustomize build $path")
    continue
  fi
  echo "${GREEN}  ✓${OFF} kustomize build"

  # 2. schema validation, Secrets skipped (see header)
  if [[ $have_kubeconform -eq 0 ]]; then
    :
  elif out=$(printf '%s\n' "$build" | kubeconform \
    -summary -strict -skip Secret -ignore-missing-schemas \
    -schema-location default \
    -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' 2>&1); then
    echo "${GREEN}  ✓${OFF} kubeconform ${DIM}(${out##*$'\n'})${OFF}"
  else
    echo "${RED}  ✗ kubeconform${OFF}"
    printf '%s\n' "$out" | sed 's/^/      /'
    failures+=("kubeconform $path")
  fi

  # 3. optional: what only the live API server knows — CRDs actually installed, admission
  #    webhooks, defaulting, immutable fields.
  if [[ $server -eq 1 ]]; then
    if out=$(printf '%s\n' "$build" | strip_secrets | kubectl apply --dry-run=server -f - 2>&1); then
      echo "${GREEN}  ✓${OFF} kubectl apply --dry-run=server ${DIM}(Secrets excluded)${OFF}"
    else
      echo "${RED}  ✗ kubectl apply --dry-run=server${OFF}"
      printf '%s\n' "$out" | grep -iE '^(error|the )' | cut -c1-400 | sed 's/^/      /'
      failures+=("dry-run $path")
    fi
  fi
done

# The node addresses baked into a few NetworkPolicies are only checkable against a
# live cluster, so this rides along with --server rather than running in CI.
if [[ $server -eq 1 ]]; then
  echo "${BOLD}==> node addresses${OFF}"
  if out=$("$script_dir/check-node-ip.sh" 2>&1); then
    echo "${GREEN}  ✓${OFF} hardcoded node addresses match the cluster"
  else
    echo "${RED}  ✗ node addresses${OFF}"
    printf '%s\n' "$out" | sed 's/^/      /'
    failures+=("node addresses")
  fi
fi

if [[ ${#failures[@]} -gt 0 ]]; then
  echo
  echo "${RED}${BOLD}${#failures[@]} check(s) failed:${OFF}"
  printf '  - %s\n' "${failures[@]}"
  exit 1
fi

echo
echo "${GREEN}${BOLD}all checks passed${OFF}"
