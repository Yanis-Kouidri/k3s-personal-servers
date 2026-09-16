#!/usr/bin/env bash
# Check that the node addresses hardcoded in NetworkPolicies still match reality.
#
# A few policies have to name the node literally. k3s evaluates egress rules AFTER
# the service DNAT, so a rule targeting the 10.43.0.1 ClusterIP never matches --
# by the time the policy runs the packet is already addressed to the node. Nor is
# there a selector for the API server: k3s runs it in the host process, not as a
# pod, so no podSelector can reach it.
#
# The duplication is survivable. What is not survivable is nobody noticing when
# the VPS changes address, because the symptoms are silent and look unrelated:
# cert-manager stops issuing certificates, the Envoy control plane stops watching
# the API and keeps serving stale backend IPs, the job-monitor stops reporting
# failed Jobs. Nothing crashes; things simply stop happening.
#
# Every literal that means "this node" carries a `# node-address` marker, and this
# compares them against what the cluster actually reports.
#
# Usage: scripts/check-node-ip.sh
set -uo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if [[ -t 1 ]]; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; BOLD=$'\033[1m'; OFF=$'\033[0m'
else
  RED=; GREEN=; BOLD=; OFF=
fi

command -v kubectl >/dev/null 2>&1 || { echo "kubectl is not installed" >&2; exit 1; }

mapfile -t node_addrs < <(kubectl get node -o jsonpath='{range .items[*].status.addresses[?(@.type=="InternalIP")]}{.address}{"\n"}{end}' 2>/dev/null)
if [[ ${#node_addrs[@]} -eq 0 ]]; then
  echo "${RED}could not read the node addresses from the cluster${OFF}" >&2
  exit 1
fi

mapfile -t hits < <(git grep -n 'node-address' -- '*.yaml' || true)
if [[ ${#hits[@]} -eq 0 ]]; then
  echo "${RED}no line carries a '# node-address' marker -- has the marker been dropped?${OFF}" >&2
  exit 1
fi

echo "${BOLD}node reports:${OFF} ${node_addrs[*]}"
status=0
for hit in "${hits[@]}"; do
  file=${hit%%:*}
  rest=${hit#*:}
  line=${rest%%:*}
  # the address as written, with any prefix length removed
  ip=$(printf '%s' "$rest" | sed -n 's/.*cidr:[[:space:]]*\([^[:space:]/]*\).*/\1/p')
  [[ -n $ip ]] || continue
  found=0
  for a in "${node_addrs[@]}"; do [[ $ip == "$a" ]] && found=1; done
  if [[ $found -eq 1 ]]; then
    printf '  %sok%s   %s:%s\n' "$GREEN" "$OFF" "$file" "$line"
  else
    printf '  %sx%s    %s:%s says %s\n' "$RED" "$OFF" "$file" "$line" "$ip"
    status=1
  fi
done

if [[ $status -ne 0 ]]; then
  echo
  echo "${RED}${BOLD}A policy names an address this node does not have.${OFF}"
  echo "Update the lines above to one of: ${node_addrs[*]}"
fi
exit "$status"
