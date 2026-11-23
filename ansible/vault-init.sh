#!/usr/bin/env bash
# Pravi tajne pri prvom pokretanju. Ništa od ovoga nije u Gitu (AO-9).
set -euo pipefail
cd "$(dirname "$0")"

# 1. lozinka za Vault (nasumična)
if [ ! -f .vault_pass ]; then
  openssl rand -base64 24 > .vault_pass
  chmod 600 .vault_pass
  echo "napravljen .vault_pass"
fi

# 2. šifrovana datoteka s tajnama (nasumična lozinka baze)
mkdir -p group_vars/all
if [ ! -f group_vars/all/vault.yml ]; then
  echo "vault_db_password: \"$(openssl rand -hex 16)\"" > group_vars/all/vault.yml
  ansible-vault encrypt group_vars/all/vault.yml
  echo "napravljen group_vars/all/vault.yml"
fi

# TSIG ključ: "propusnica" kojom Terraform dokazuje BIND-u da smije mijenjati zonu
mkdir -p group_vars/dns_servers
if [ ! -f group_vars/dns_servers/vault.yml ]; then
  TSIG=$(openssl rand -base64 32)
  echo "vault_tsig_secret: \"$TSIG\"" > group_vars/dns_servers/vault.yml
  ansible-vault encrypt group_vars/dns_servers/vault.yml
  echo "napravljen TSIG ključ"
fi
