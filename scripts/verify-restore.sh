#!/usr/bin/env bash
# Restore a database backup into a throwaway PostgreSQL and check it against
# production. A backup nobody has ever restored is not a backup.
#
# Usage:
#   scripts/verify-restore.sh [app ...]     (default: immich n8n sonarqube)
#
# What it does, per app:
#   1. starts a scratch PostgreSQL pod in the app's namespace, with an emptyDir
#      for its data and the backup PVC mounted READ-ONLY
#   2. restores the most recent dump into it (psql for plain SQL, pg_restore for
#      the custom format)
#   3. compares the table count and a few business tables against the live
#      database
#   4. deletes the pod
#
# Production is only ever read. The restore happens in a container of its own
# with its own empty data directory, so there is no path from this script to the
# running databases.
#
# Row counts of append-only tables (executions, issues) are expected to have
# grown since the dump was taken; only a SMALLER restored count is a failure.
set -uo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; OFF=$'\033[0m'
else
  BOLD=; RED=; GREEN=; YELLOW=; DIM=; OFF=
fi

POD=restore-verify

# app|namespace|backup PVC|scratch image|dump glob|production pod|db|roles|tables
#
# `roles` are roles the dump expects to already exist. A plain-SQL dump carries
# `ALTER TABLE ... OWNER TO <role>` statements and psql stops on the first one
# whose role is missing: restoring SonarQube into a bare PostgreSQL fails on line
# 29 with `role "sonar" does not exist`. pg_restore is given --no-owner instead,
# so the custom-format dump (n8n) needs nothing here.
APPS=(
  "immich|immich|backup-immich-pvc|ghcr.io/immich-app/postgres:18-vectorchord0.5.3-pgvector0.8.1|*.sql|postgres-immich-db-0|immich||asset person album"
  "n8n|n8n|backup-n8n-pvc|postgres:18.6|*.dump|postgres-0|n8n||workflow_entity credentials_entity"
  "sonarqube|sonarqube|backup-sonarqube-pvc|postgres:18.6|*.sql|postgres-sonarqube-postgresql-0|sonar|sonar|projects rules"
)

# Each image exposes its superuser password differently; this is what works in
# each production pod (checked against the running containers).
prod_psql() {
  local app=$1 ns=$2 pod=$3 db=$4 query=$5
  case "$app" in
    immich)    kubectl exec -n "$ns" "$pod" -- psql -U postgres -d "$db" -tAc "$query" 2>/dev/null ;;
    n8n)       kubectl exec -n "$ns" "$pod" -- sh -c \
                 "PGPASSWORD=\$POSTGRES_PASSWORD psql -U \$POSTGRES_USER -d $db -tAc \"$query\"" 2>/dev/null ;;
    sonarqube) kubectl exec -n "$ns" "$pod" -- sh -c \
                 "PGPASSWORD=\$(cat \$POSTGRES_PASSWORD_FILE) psql -U sonar -d $db -tAc \"$query\"" 2>/dev/null ;;
  esac | tr -d '\r' | tr -d '[:space:]'
}

cleanup() { kubectl delete pod "$POD" -n "${CURRENT_NS:-default}" --ignore-not-found --wait=false >/dev/null 2>&1; }
trap cleanup EXIT

failures=()

verify_app() {
  local app=$1 ns=$2 pvc=$3 image=$4 glob=$5 prodpod=$6 db=$7 roles=$8 tables=$9
  CURRENT_NS=$ns
  echo "${BOLD}==> $app${OFF}"

  kubectl delete pod "$POD" -n "$ns" --ignore-not-found --wait=true >/dev/null 2>&1

  # automountServiceAccountToken: false -- this pod has no business talking to
  # the API, same rule as every other workload in the cluster.
  if ! kubectl apply -f - >/dev/null 2>&1 <<YAML
apiVersion: v1
kind: Pod
metadata:
  name: $POD
  namespace: $ns
spec:
  restartPolicy: Never
  automountServiceAccountToken: false
  containers:
    - name: pg
      image: $image
      env:
        - {name: POSTGRES_PASSWORD, value: verify-restore-scratch}
        - {name: PGDATA, value: /var/lib/postgresql/data/pgdata}
      volumeMounts:
        - {name: data, mountPath: /var/lib/postgresql}
        - {name: backups, mountPath: /backups, readOnly: true}
  volumes:
    - {name: data, emptyDir: {}}
    - name: backups
      persistentVolumeClaim: {claimName: $pvc, readOnly: true}
YAML
  then
    echo "${RED}  x could not start the scratch pod${OFF}"; failures+=("$app: scratch pod"); return
  fi

  local deadline=$(( $(date +%s) + 300 ))
  until kubectl exec -n "$ns" "$POD" -- pg_isready -q >/dev/null 2>&1; do
    if [[ $(date +%s) -ge $deadline ]]; then
      echo "${RED}  x scratch PostgreSQL never came up${OFF}"; failures+=("$app: scratch pod never ready"); return
    fi
    sleep 5
  done
  echo "${GREEN}  ok${OFF} scratch PostgreSQL ready ${DIM}($image)${OFF}"

  local out
  out=$(kubectl exec -n "$ns" "$POD" -- sh -c "
    set -e
    for r in $roles; do createuser -U postgres \"\$r\" 2>/dev/null || true; done
    DUMP=\$(ls -t /backups/$glob 2>/dev/null | head -1)
    [ -n \"\$DUMP\" ] || { echo 'NO_DUMP'; exit 1; }
    [ -s \"\$DUMP\" ] || { echo \"EMPTY_DUMP \$DUMP\"; exit 1; }
    echo \"DUMP \$DUMP \$(du -h \"\$DUMP\" | cut -f1)\"
    createdb -U postgres verify_restore
    case \"\$DUMP\" in
      *.dump) pg_restore -U postgres -d verify_restore --no-owner --no-privileges \"\$DUMP\" ;;
      *)      psql -U postgres -d verify_restore -v ON_ERROR_STOP=1 -q -f \"\$DUMP\" ;;
    esac
  " 2>&1)
  local rc=$?
  local dumpline
  dumpline=$(echo "$out" | grep '^DUMP ' | head -1)
  if [[ $rc -ne 0 ]]; then
    echo "${RED}  x restore failed${OFF}"
    echo "$out" | grep -viE '^dump |defaulted' | head -5 | sed 's/^/      /'
    failures+=("$app: restore"); return
  fi
  echo "${GREEN}  ok${OFF} restored ${DIM}${dumpline#DUMP }${OFF}"

  # --- compare against production -----------------------------------------
  local q_tables="SELECT count(*) FROM information_schema.tables WHERE table_schema='public';"
  local r p
  r=$(kubectl exec -n "$ns" "$POD" -- psql -U postgres -d verify_restore -tAc "$q_tables" 2>/dev/null | tr -d '[:space:]')
  p=$(prod_psql "$app" "$ns" "$prodpod" "$db" "$q_tables")
  if [[ -z "$p" ]]; then
    echo "${YELLOW}  skip${OFF} table count ${DIM}(production unreachable)${OFF}"
  elif [[ "$r" == "$p" ]]; then
    echo "${GREEN}  ok${OFF} $r tables, same as production"
  else
    echo "${RED}  x tables: production=$p restored=$r${OFF}"; failures+=("$app: table count")
  fi

  local t
  for t in $tables; do
    # Unquoted table names on purpose: quoting them would need escaping through
    # bash, kubectl exec and sh -c, and a wrong layer returns nothing silently
    # rather than failing. None of the tables compared here needs quoting.
    local q="SELECT count(*) FROM $t;"
    r=$(kubectl exec -n "$ns" "$POD" -- psql -U postgres -d verify_restore -tAc "$q" 2>/dev/null | tr -d '[:space:]')
    p=$(prod_psql "$app" "$ns" "$prodpod" "$db" "$q")
    if [[ -z "$r" || -z "$p" ]]; then
      echo "${YELLOW}  skip${OFF} $t ${DIM}(not comparable)${OFF}"
    elif [[ "$r" -eq "$p" ]]; then
      echo "${GREEN}  ok${OFF} $t: $r rows, same as production"
    elif [[ "$r" -lt "$p" ]]; then
      echo "${GREEN}  ok${OFF} $t: $r rows ${DIM}(production has $p; it has grown since the dump)${OFF}"
    else
      echo "${RED}  x $t: restored=$r is MORE than production=$p${OFF}"; failures+=("$app: $t")
    fi
  done

  kubectl delete pod "$POD" -n "$ns" --ignore-not-found --wait=false >/dev/null 2>&1
}

targets=("$@")
[[ ${#targets[@]} -eq 0 ]] && targets=(immich n8n sonarqube)

for want in "${targets[@]}"; do
  found=0
  for row in "${APPS[@]}"; do
    IFS='|' read -r app ns pvc image glob prodpod db roles tables <<<"$row"
    [[ "$app" == "$want" ]] || continue
    found=1
    verify_app "$app" "$ns" "$pvc" "$image" "$glob" "$prodpod" "$db" "$roles" "$tables"
  done
  [[ $found -eq 1 ]] || { echo "${RED}unknown app: $want${OFF}" >&2; failures+=("unknown app: $want"); }
done

echo
if [[ ${#failures[@]} -gt 0 ]]; then
  echo "${RED}${BOLD}${#failures[@]} check(s) failed:${OFF}"
  printf '  - %s\n' "${failures[@]}"
  exit 1
fi
echo "${GREEN}${BOLD}every backup restored and matched production${OFF}"
