#!/usr/bin/env bash
# Verify that every *.enc.yaml is a real SOPS document with ciphertext-only values.
#
# This NEVER decrypts anything (no age key is needed, by design). It only checks that:
#   1. the file has a top-level `sops:` metadata block;
#   2. every value nested under `data:` / `stringData:` is `ENC[...]` ciphertext and not
#      plaintext that slipped in without being (re-)encrypted.
#
# Shared by the CI job `verify-sops-encryption` and by the pre-commit hook, so both
# enforce exactly the same rule. Emits GitHub Actions annotations when run in CI.
#
# Usage: check-sops-encryption.sh [file ...]   (no args = every *.enc.yaml in the tree)
set -uo pipefail

err() {
  local file=$1 msg=$2
  if [[ -n ${GITHUB_ACTIONS:-} ]]; then
    echo "::error file=${file}::${msg}"
  else
    echo "  ✗ ${file}: ${msg}" >&2
  fi
}

check_file() {
  local f=$1 rc=0

  if ! grep -qE '^sops:' "$f"; then
    err "$f" "not SOPS-encrypted (no top-level 'sops:' block)"
    return 1
  fi

  # Walk the data:/stringData: blocks and require ENC[...] on every leaf value.
  awk -v file="$f" -v gha="${GITHUB_ACTIONS:-}" '
    /^(data|stringData):[[:space:]]*$/ { in_block=1; next }
    /^[A-Za-z]/                       { in_block=0 }
    in_block && /^[[:space:]]+[A-Za-z0-9_.-]+:/ {
      if ($0 !~ /:[[:space:]]*ENC\[/) {
        msg = "possible plaintext value -> " $0
        if (gha != "") print "::error file=" file "::" msg
        else           print "  ✗ " file ": " msg > "/dev/stderr"
        bad = 1
      }
    }
    END { exit bad }
  ' "$f" || rc=1

  return "$rc"
}

files=("$@")
if [[ ${#files[@]} -eq 0 ]]; then
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find . -iname '*.enc.yaml' -not -path './.git/*' -print0)
fi

status=0
for f in "${files[@]}"; do
  [[ -f $f ]] || continue
  echo "Checking $f"
  check_file "$f" || status=1
done

exit "$status"
