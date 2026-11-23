#!/usr/bin/env bash
# AO-8: drift. Zapis koji vodi Terraform mijenjamo "ručno" (nsupdate s ključem, mimo koda).
# Terraform to mora primijetiti (plan), a apply vraća stanje iz koda.
source "$(dirname "$0")/common.sh"
echo "== drift: ručna izmjena DNS-a"
ZONA=projekat.lab
TF="terraform -chdir=$KOREN/terraform/dns"
D="dig +short +time=3 +tries=1 @$DNS_IP"

S=$("$KOREN/ansible/tsig-secret.sh") || { echo "nema TSIG tajne (make config)" >&2; exit 1; }
export TF_VAR_tsig_secret="$S"
KLJUC=$(mktemp)
trap 'rm -f "$KLJUC"' EXIT
printf 'key "ruo-tf" {\n  algorithm hmac-sha256;\n  secret "%s";\n};\n' "$S" > "$KLJUC"

treba_uspjeti "prije izmjene nema drifta (plan exit 0)" $TF plan -detailed-exitcode -input=false

echo "  ... neko ručno mijenja app.$ZONA na 10.40.2.99 (nsupdate, mimo Terraforma)"
nsupdate -k "$KLJUC" <<UPDATE
server $DNS_IP
zone $ZONA
update delete app.$ZONA. A
update add app.$ZONA. 300 A 10.40.2.99
send
UPDATE
jednako "ručna izmjena je stvarno upisana u DNS" "10.40.2.99" "$($D app.$ZONA A)"

echo "  --- terraform plan (očekujemo razliku):"
$TF plan -detailed-exitcode -input=false -no-color | sed 's/^/      /'
RC=${PIPESTATUS[0]}
if [ "$RC" -eq 2 ]; then ok "plan je primijetio drift (exit 2)"; else pao "plan je trebao vratiti exit 2, a vratio je $RC"; fi

echo "  --- terraform apply (vraća stanje iz koda):"
$TF apply -auto-approve -input=false -no-color | sed 's/^/      /'
jednako "app.$ZONA ponovo pokazuje na adresu app VM-a" "$APP_IP" "$($D app.$ZONA A)"
treba_uspjeti "poslije popravke nema drifta (plan exit 0)" $TF plan -detailed-exitcode -input=false

kraj
