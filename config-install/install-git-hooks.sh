#!/usr/bin/env bash
# Install the repo's git hooks (.githooks/) for this clone.
#
# git hooks live in .git/hooks, which is not versioned, so `core.hooksPath` is pointed at
# the versioned .githooks/ directory instead — one command per clone, then every hook
# update arrives with a normal `git pull`.
#
#   config-install/install-git-hooks.sh                  install the hooks
#   config-install/install-git-hooks.sh --install-tools   + install the optional linters
#   config-install/install-git-hooks.sh --uninstall       remove the hooks
#
# The optional linters (yamllint, kubeconform, gitleaks, actionlint) are pinned to the
# exact versions used by .github/workflows/build.yml and installed into ~/.local/bin.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

workflow=.github/workflows/build.yml
bin_dir="${HOME}/.local/bin"

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; OFF=$'\033[0m'
else
  BOLD=; RED=; GREEN=; YELLOW=; OFF=
fi

usage() { sed -nE 's/^# ?//p' "$0" | head -12; }

ci_version() {
  local v
  v=$(sed -nE "s/^[[:space:]]*$1:[[:space:]]*\"([^\"]+)\".*/\1/p" "$workflow" | head -1)
  [[ -n $v ]] || { echo "${RED}cannot read $1 from $workflow${OFF}" >&2; return 1; }
  printf '%s' "$v"
}

# Download an archive + its checksum file, verify sha256, extract one binary into ~/.local/bin.
install_binary() {
  local name=$1 archive_url=$2 checksum_url=$3 grep_pattern=$4 member=$5
  local tmp
  tmp=$(mktemp -d)
  # shellcheck disable=SC2064  # expand $tmp now, on purpose
  trap "rm -rf '$tmp'" RETURN

  echo "  downloading $name"
  curl -sSLf -o "$tmp/archive.tar.gz" "$archive_url"
  curl -sSLf -o "$tmp/checksums.txt" "$checksum_url"
  ( cd "$tmp" && sha256sum -c <(grep "$grep_pattern" checksums.txt | sed 's#[^ ]*$#archive.tar.gz#') >/dev/null )
  tar -xzf "$tmp/archive.tar.gz" -C "$tmp" "$member"
  install -Dm755 "$tmp/$member" "$bin_dir/$name"
  echo "  ${GREEN}installed${OFF} $bin_dir/$name"
}

install_tools() {
  local arch tmp
  arch=$(uname -m)
  if [[ $(uname -s) != Linux || $arch != x86_64 ]]; then
    echo "${YELLOW}--install-tools only knows linux/x86_64 (got $(uname -s)/$arch); install the tools manually${OFF}" >&2
    return 1
  fi

  mkdir -p "$bin_dir"

  # yamllint: installed (not `pipx run`) so the hook also works offline.
  local yamllint_version
  yamllint_version=$(sed -nE 's/.*yamllint==([0-9][A-Za-z0-9._-]*).*/\1/p' "$workflow" | head -1)
  if command -v pipx >/dev/null 2>&1; then
    echo "  installing yamllint==${yamllint_version}"
    pipx install --force "yamllint==${yamllint_version}" >/dev/null
    echo "  ${GREEN}installed${OFF} yamllint ${yamllint_version}"
  else
    echo "  ${YELLOW}pipx not found — install it, or install yamllint==${yamllint_version} yourself${OFF}"
  fi

  local v
  v=$(ci_version KUBECONFORM_VERSION)
  install_binary kubeconform \
    "https://github.com/yannh/kubeconform/releases/download/v${v}/kubeconform-linux-amd64.tar.gz" \
    "https://github.com/yannh/kubeconform/releases/download/v${v}/CHECKSUMS" \
    "kubeconform-linux-amd64.tar.gz" kubeconform

  v=$(ci_version GITLEAKS_VERSION)
  install_binary gitleaks \
    "https://github.com/gitleaks/gitleaks/releases/download/v${v}/gitleaks_${v}_linux_x64.tar.gz" \
    "https://github.com/gitleaks/gitleaks/releases/download/v${v}/gitleaks_${v}_checksums.txt" \
    "linux_x64.tar.gz" gitleaks

  # The shellcheck release is a .tar.xz with the binary nested in a directory, and
  # upstream publishes no checksum file, so it does not fit install_binary().
  v=$(ci_version SHELLCHECK_VERSION)
  echo "  downloading shellcheck"
  tmp=$(mktemp -d)
  curl -sSLf -o "$tmp/shellcheck.tar.xz" \
    "https://github.com/koalaman/shellcheck/releases/download/v${v}/shellcheck-v${v}.linux.x86_64.tar.xz"
  tar -xJf "$tmp/shellcheck.tar.xz" -C "$tmp" "shellcheck-v${v}/shellcheck"
  install -Dm755 "$tmp/shellcheck-v${v}/shellcheck" "$bin_dir/shellcheck"
  rm -rf "$tmp"
  echo "  ${GREEN}installed${OFF} $bin_dir/shellcheck"

  v=$(ci_version ACTIONLINT_VERSION)
  install_binary actionlint \
    "https://github.com/rhysd/actionlint/releases/download/v${v}/actionlint_${v}_linux_amd64.tar.gz" \
    "https://github.com/rhysd/actionlint/releases/download/v${v}/actionlint_${v}_checksums.txt" \
    "linux_amd64.tar.gz" actionlint

  case ":$PATH:" in
    *":$bin_dir:"*) ;;
    *) echo "  ${YELLOW}note: $bin_dir is not in your PATH${OFF}" ;;
  esac
}

report_tools() {
  echo
  echo "${BOLD}Tooling used by the hooks${OFF}"
  local required=(git kustomize) optional=(kubeconform gitleaks actionlint shellcheck) t
  for t in "${required[@]}"; do
    if command -v "$t" >/dev/null 2>&1; then
      printf '  %sok  %s %-13s %s\n' "$GREEN" "$OFF" "$t" "$(command -v "$t")"
    else
      printf '  %sMISSING%s %-9s required — the hook will fail without it\n' "$RED" "$OFF" "$t"
    fi
  done
  if command -v yamllint >/dev/null 2>&1; then
    printf '  %sok  %s %-13s %s\n' "$GREEN" "$OFF" "yamllint" "$(command -v yamllint)"
  elif command -v pipx >/dev/null 2>&1 || command -v uvx >/dev/null 2>&1; then
    printf '  %sok  %s %-13s via pipx/uvx (needs network on first run — see --install-tools)\n' "$GREEN" "$OFF" "yamllint"
  else
    printf '  %sMISSING%s %-9s required — no yamllint, pipx or uvx found\n' "$RED" "$OFF" "yamllint"
  fi
  for t in "${optional[@]}"; do
    if command -v "$t" >/dev/null 2>&1; then
      printf '  %sok  %s %-13s %s\n' "$GREEN" "$OFF" "$t" "$(command -v "$t")"
    else
      printf '  %s--  %s %-13s optional — that check is skipped (see --install-tools)\n' "$YELLOW" "$OFF" "$t"
    fi
  done
}

case "${1:-}" in
  --uninstall)
    git config --unset core.hooksPath || true
    echo "${GREEN}git hooks uninstalled${OFF} (core.hooksPath unset)"
    exit 0
    ;;
  --install-tools)
    echo "${BOLD}Installing the linters pinned in $workflow${OFF}"
    install_tools
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  "") ;;
  *)
    echo "unknown option: $1" >&2
    usage >&2
    exit 2
    ;;
esac

chmod +x .githooks/* scripts/*.sh
git config core.hooksPath .githooks
echo "${GREEN}git hooks installed${OFF} (core.hooksPath=.githooks)"
echo "  pre-commit  yamllint, kustomize build, kubeconform, SOPS/secret checks, actionlint, gitleaks, shellcheck"
echo "  commit-msg  conventional commit format"
report_tools
