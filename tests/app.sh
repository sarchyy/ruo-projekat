#!/usr/bin/env bash
# AO-1: aplikacija radi kroz jedini objavljeni port, a sva tri kontejnera su zdrava.
source "$(dirname "$0")/common.sh"
echo "== app: aplikacija i kontejneri"

treba_uspjeti "početna stranica odgovara na portu 80" curl -fsS --max-time 5 "http://$APP_IP/"

A=$(curl -fsS --max-time 5 "http://$APP_IP/api/posjete" | sed 's/[^0-9]//g')
B=$(curl -fsS --max-time 5 "http://$APP_IP/api/posjete" | sed 's/[^0-9]//g')
if [ -n "$A" ] && [ -n "$B" ] && [ "$B" -eq $((A + 1)) ]; then
  ok "brojač posjeta raste ($A -> $B)"
else
  pao "brojač posjeta raste ($A -> $B)"
fi

ZDRAVIH=$(na_app sudo docker ps --filter health=healthy -q | wc -l)
if [ "$ZDRAVIH" -eq 3 ]; then ok "sva tri kontejnera su zdrava (healthy)"; else pao "zdravih kontejnera: $ZDRAVIH (treba 3)"; fi

PORTOVI=$(na_app sudo docker ps --format '{{.Names}} {{.Ports}}')
OBJAVLJENO=$(echo "$PORTOVI" | grep -c -- '->')
if [ "$OBJAVLJENO" -eq 1 ] && echo "$PORTOVI" | grep -q 'frontend.*80->80'; then
  ok "objavljen je samo jedan port: 80 na frontendu"
else
  pao "objavljenih portova: $OBJAVLJENO (treba samo 80 na frontendu)"
fi

kraj
