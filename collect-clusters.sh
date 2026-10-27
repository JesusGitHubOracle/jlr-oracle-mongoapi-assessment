#!/usr/bin/env bash
# Usage: bash collect-clusters.sh clusters.txt ./captures /path/to/mongoserverStatus.sh
# Input: one cluster-name|MongoDB-URI per line. Keep this file private.
set -u
umask 077
LIST=${1:-clusters.txt}
OUTPUT=${2:-./captures}
SCRIPT=${3:-/Users/jlrobles/Documents/GitHub/jlr-oracle-mongodb-api/migration/mongoserverStatus.sh}
for dependency in mongosh jq; do
  command -v "$dependency" >/dev/null || { echo "Missing dependency: $dependency" >&2; exit 1; }
done
[[ -f "$LIST" && -f "$SCRIPT" ]] || { echo 'Cluster list or extraction script not found.' >&2; exit 1; }
mkdir -p "$OUTPUT" || exit 1
run_id="$(date -u +%Y%m%dT%H%M%SZ)_$$"
failed=0
while IFS='|' read -r cluster uri || [[ -n "$cluster" ]]; do
  [[ -z "$cluster" || "$cluster" == \#* ]] && continue
  uri=${uri%$'\r'}
  if [[ ! "$cluster" =~ ^[a-zA-Z0-9_-]+$ || ! "$uri" =~ ^mongodb(\+srv)?:// ]]; then
    echo 'Invalid line: use cluster-name|mongodb://... or cluster-name|mongodb+srv://...' >&2
    failed=1; continue
  fi
  cluster_dir="$OUTPUT/$cluster"
  mkdir -p "$cluster_dir" || { failed=1; continue; }
  echo "Collecting $cluster"
  # The original script pauses for Enter and adds its own timestamp to --out.
  # Supply the URI via its supported environment variable and suppress URI console output.
  MONGDB_URI="$uri" bash "$SCRIPT" \
    --out "$cluster_dir/serverStatus_${run_id}.json" \
    <<< '' >/dev/null 2>&1
  command_status=$?
  files=( "$cluster_dir/"*"_serverStatus_${run_id}.json" )
  if [[ $command_status -eq 0 && ${#files[@]} -eq 1 ]] && \
     jq -e 'type == "object" and .ok == 1 and has("uptime") and has("version")' \
       "${files[0]}" >/dev/null 2>&1; then
    echo "Saved: ${files[0]}"
  else
    echo "Failed: $cluster. Check its URI, network access and serverStatus permissions." >&2
    for file in "${files[@]}"; do [[ -f "$file" ]] && rm -f "$file"; done
    failed=1
  fi
done < "$LIST"
exit "$failed"
