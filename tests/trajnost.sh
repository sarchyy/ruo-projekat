#!/usr/bin/env bash
# AO-10: podaci žive u imenovanom volumenu, pa prežive brisanje kontejnera baze.
source "$(dirname "$0")/common.sh"
echo "== trajnost: brisanje kontejnera baze"
COMPOSE="sudo docker compose --project-directory /opt/ruo"
posjete() { curl -fsS --retry 5 --retry-delay 2 --max-time 10 "http://$APP_IP/api/posjete" | sed 's/[^0-9]//g'; }

volumen_postoji() { na_app sudo docker volume ls -q | grep -qx ruo_dbdata; }
treba_uspjeti "imenovani volumen ruo_dbdata postoji" volumen_postoji

PRIJE=$(posjete)
echo "  brojač prije brisanja kontejnera baze: $PRIJE"

na_app $COMPOSE rm -sf db >/dev/null 2>&1
echo "  kontejner baze je obrisan, pravim novi (isti volumen)"
na_app $COMPOSE up -d db >/dev/null 2>&1
for i in $(seq 1 30); do
  [ "$(na_app sudo docker ps --filter health=healthy -q | wc -l)" -eq 3 ] && break
  sleep 2
done

POSLIJE=$(posjete)
echo "  brojač poslije: $POSLIJE"
if [ -n "$PRIJE" ] && [ -n "$POSLIJE" ] && [ "$POSLIJE" -eq $((PRIJE + 1)) ]; then
  ok "podaci su preživjeli novi kontejner baze ($PRIJE -> $POSLIJE)"
else
  pao "brojač nakon novog kontejnera: $POSLIJE (očekivano $((PRIJE + 1)))"
fi

kraj
