#!/usr/bin/env bash
# Install the host firewall (config-install/host-firewall.nft) with an automatic rollback.
#
#   config-install/install-host-firewall.sh              load the rules, arm a rollback
#   config-install/install-host-firewall.sh --confirm    keep them: cancel rollback, enable at boot
#   config-install/install-host-firewall.sh --uninstall  remove the rules and the unit
#
# The first step loads the table and schedules its deletion in ROLLBACK_SECONDS (180 by
# default). Open a NEW ssh session and check the public services before running
# --confirm: if anything is locked out, doing nothing is enough, the rules go away.
# Established connections survive the load, so the current session is not a valid test.
#
# Re-run the first step after editing host-firewall.nft; --confirm reloads the unit.
set -euo pipefail

repo_root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
src_rules="$repo_root/config-install/host-firewall.nft"
src_unit="$repo_root/config-install/host-firewall.service"
dst_rules=/etc/host-firewall.nft
dst_unit=/etc/systemd/system/host-firewall.service
rollback_unit=host-firewall-rollback
rollback_seconds=${ROLLBACK_SECONDS:-180}

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; OFF=$'\033[0m'
else
  BOLD=; RED=; GREEN=; YELLOW=; OFF=
fi

usage() { sed -nE 's/^# ?//p' "$0" | head -12; }

cancel_rollback() {
  sudo systemctl stop "$rollback_unit.timer" "$rollback_unit.service" 2>/dev/null || true
  sudo systemctl reset-failed "$rollback_unit.timer" "$rollback_unit.service" 2>/dev/null || true
}

apply() {
  sudo nft -c -f "$src_rules"
  cancel_rollback
  sudo install -m 0644 "$src_rules" "$dst_rules"
  sudo install -m 0644 "$src_unit" "$dst_unit"
  sudo systemctl daemon-reload

  # Armed before loading, so a lockout can never leave the rules in place.
  sudo systemd-run --quiet --unit="$rollback_unit" --on-active="$rollback_seconds" \
    /usr/sbin/nft delete table inet host-fw
  sudo nft -f "$dst_rules"

  echo "${GREEN}host-fw loaded.${OFF} ${YELLOW}Rollback in ${rollback_seconds}s.${OFF}"
  echo "From another machine, open a NEW ssh session and check the public services, then:"
  echo "  ${BOLD}$0 --confirm${OFF}"
}

confirm() {
  sudo nft list table inet host-fw >/dev/null 2>&1 \
    || { echo "${RED}host-fw is not loaded (rollback already fired?), run $0 first${OFF}" >&2; exit 1; }
  cancel_rollback
  sudo systemctl enable host-firewall.service
  # restart, not start: RemainAfterExit keeps a stale unit "active" after an edit.
  sudo systemctl restart host-firewall.service
  echo "${GREEN}host-fw confirmed and enabled at boot.${OFF}"
}

uninstall() {
  cancel_rollback
  sudo systemctl disable --now host-firewall.service 2>/dev/null || true
  sudo nft delete table inet host-fw 2>/dev/null || true
  sudo rm -f "$dst_unit" "$dst_rules"
  sudo systemctl daemon-reload
  echo "${GREEN}host-fw removed.${OFF}"
}

case "${1:-}" in
  "") apply ;;
  --confirm) confirm ;;
  --uninstall) uninstall ;;
  -h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
