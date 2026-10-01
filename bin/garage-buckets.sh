#!/usr/bin/env bash
# Creates the Garage bucket for each static site and makes it servable.
#
# Idempotent: re-run after adding a hostname to kubernetes/production.vars.yaml. Garage
# itself has no public access, so a site is only reachable through the web endpoint once
# website access is allowed on its bucket (bucket name = hostname, which is how the web
# endpoint picks the bucket from the Host header).
#
# Grants: the `static` key writes (burns and migrations), `garage-backup-reader` reads
# (the off-site mirror in infrastructure/kubernetes/garage/backup.cronjob-sync.yaml).
#
# Usage:
#   bin/garage-buckets.sh                      # every hostname in production.vars.yaml
#   bin/garage-buckets.sh 2024.tracon.fi ...   # just these
set -euo pipefail

cd "$(dirname "$0")/.."

garage() {
  kubectl -n garage exec garage-0 -c garage -- /garage "$@"
}

if [ $# -gt 0 ]; then
  hostnames=("$@")
else
  # The static_sites list is the first block of production.vars.yaml, one "  - host" per line.
  mapfile -t hostnames < <(sed -n '/^static_sites:/,/^$/p' kubernetes/production.vars.yaml | sed -n 's/^  - //p')
fi

existing=$(garage bucket list | awk 'NR>1 {print $3}')

for hostname in "${hostnames[@]}"; do
  if ! grep -qx "$hostname" <<<"$existing"; then
    garage bucket create "$hostname"
  fi
  garage bucket website --allow "$hostname"
  garage bucket allow --read --write "$hostname" --key static
  garage bucket allow --read "$hostname" --key garage-backup-reader
done
