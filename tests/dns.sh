#!/usr/bin/env bash
# AO-7 i AO-8: BIND odgovara za zonu, ne radi rekurziju, odbija nepotpisane izmjene,
# a Terraform ne vidi razliku između koda i stvarnog stanja DNS-a.
source "$(dirname "$0")/common.sh"
echo "== dns: zona projekat.lab"
ZONA=projekat.lab
D="dig +short +time=3 +tries=1 @$DNS_IP"

treba_uspjeti "BIND je autoritativan za zonu (zastavica aa)" \
  bash -c "dig +noall +comments +time=3 +tries=1 @$DNS_IP $ZONA SOA | grep -Eq 'flags:.* aa[ ;]'"
jednako "ns1.$ZONA pokazuje na adresu dns VM-a" "$DNS_IP" "$($D ns1.$ZONA A)"
jednako "app.$ZONA pokazuje na adresu app VM-a" "$APP_IP" "$($D app.$ZONA A | tail -1)"
jednako "web.$ZONA je nadimak (CNAME) za app.$ZONA." "app.$ZONA." "$($D web.$ZONA CNAME)"
treba_uspjeti "tuđe domene se odbijaju (recursion no)" \
  bash -c "dig +noall +comments +time=3 +tries=1 @$DNS_IP google.com | grep -q 'status: REFUSED'"

izmjena_bez_kljuca() {
  printf 'server %s\nzone %s\nupdate add proba.%s. 60 A 192.0.2.1\nsend\n' "$DNS_IP" "$ZONA" "$ZONA" | nsupdate
}
treba_pasti "izmjena zone bez TSIG potpisa je odbijena" izmjena_bez_kljuca
jednako "zapis 'proba' nije nastao" "" "$($D proba.$ZONA A)"

bez_drifta() {
  local S
  S=$("$KOREN/ansible/tsig-secret.sh") || return 1
  TF_VAR_tsig_secret="$S" terraform -chdir="$KOREN/terraform/dns" plan -detailed-exitcode -input=false
}
treba_uspjeti "Terraform plan: nema razlike između koda i DNS-a (exit 0)" bez_drifta

kraj
