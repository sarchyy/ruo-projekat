#!/usr/bin/env bash
# Zajedničke pomoćne funkcije za testove (učitavaju se sa: source common.sh)
KOREN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INVENTAR="$KOREN/ansible/inventory.ini"

# adresu VM-a čitamo iz generisanog inventara, nigdje je ne kucamo ručno
ip_od() { awk -v h="$1" '$1==h {sub("ansible_host=","",$2); print $2}' "$INVENTAR"; }
APP_IP=$(ip_od app)
DNS_IP=$(ip_od dns)
if [ -z "$APP_IP" ] || [ -z "$DNS_IP" ]; then
  echo "Nema inventara. Prvo: make infra" >&2
  exit 1
fi

# naredba na app VM-u (bez pitanja o ključu domaćina, jer se VM-ovi iznova prave)
na_app() {
  ssh -n -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    "student@$APP_IP" "$(printf '%q ' "$@")"
}
# naredba unutar kontejnera: u_kont <servis> <naredba...>
u_kont() { local s=$1; shift; na_app sudo docker compose --project-directory /opt/ruo exec -T "$s" "$@"; }
# je li TCP port otvoren: port_otvoren <ip> <port>
port_otvoren() { timeout 3 bash -c "exec 3<>/dev/tcp/$1/$2" 2>/dev/null; }

PROSLO=0
PALO=0
ok()  { echo "  [OK]   $1"; PROSLO=$((PROSLO + 1)); }
pao() { echo "  [PAO]  $1"; PALO=$((PALO + 1)); }
treba_uspjeti() { local opis=$1; shift; if "$@" >/dev/null 2>&1; then ok "$opis"; else pao "$opis"; fi; }
treba_pasti()   { local opis=$1; shift; if "$@" >/dev/null 2>&1; then pao "$opis"; else ok "$opis"; fi; }
kraj() { echo "  ---- prošlo: $PROSLO, palo: $PALO"; [ "$PALO" -eq 0 ]; }
# usporedi dvije vrijednosti: jednako "opis" "očekivano" "dobijeno"
jednako() { if [ "$2" = "$3" ]; then ok "$1"; else pao "$1 (očekivano '$2', dobijeno '$3')"; fi; }
