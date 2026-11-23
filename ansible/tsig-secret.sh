#!/usr/bin/env bash
# Ispisuje TSIG tajnu iz vaulta (za Terraform). Ne upisuje je ni u kakav fajl.
set -euo pipefail
cd "$(dirname "$0")"
S=$(ansible-vault view group_vars/dns_servers/vault.yml | awk -F'"' '/vault_tsig_secret/{print $2}')
[ -n "$S" ] || { echo "TSIG tajna nije nađena (pokreni: make config)" >&2; exit 1; }
printf '%s\n' "$S"
