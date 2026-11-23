#!/usr/bin/env bash
# AO-6: tri mreže (web, app, db). Svaki sloj vidi samo susjedni sloj.
source "$(dirname "$0")/common.sh"
echo "== izolacija: segmentacija mreže"

# u kojim mrežama je servis (iz Docker metapodataka)
mreze() {
  local id
  id=$(na_app sudo docker compose --project-directory /opt/ruo ps -q "$1")
  na_app sudo docker inspect "$id" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}'
}
provjeri_mreze() {
  local stvarne
  stvarne=$(mreze "$1" | xargs)
  if [ "$stvarne" = "$2" ]; then ok "$1 je u mrežama: $2"; else pao "$1 je u mrežama '$stvarne' (treba '$2')"; fi
}
provjeri_mreze frontend "ruo_app ruo_web"
provjeri_mreze backend "ruo_app ruo_db"
provjeri_mreze db "ruo_db"

# šta stvarno može dohvatiti šta
treba_uspjeti "frontend vidi backend po imenu" u_kont frontend getent hosts backend
treba_pasti "frontend NE vidi bazu po imenu" u_kont frontend getent hosts db
treba_uspjeti "backend dohvata bazu (db:5432)" u_kont backend python -c "import socket; socket.create_connection(('db', 5432), 3)"
treba_pasti "backend NE izlazi na internet (1.1.1.1:53)" u_kont backend python -c "import socket; socket.create_connection(('1.1.1.1', 53), 3)"

# izvana (s tvog računara)
treba_uspjeti "izvana je otvoren port 80 (frontend)" port_otvoren "$APP_IP" 80
treba_pasti "izvana NIJE otvoren port 8000 (backend)" port_otvoren "$APP_IP" 8000
treba_pasti "izvana NIJE otvoren port 5432 (baza)" port_otvoren "$APP_IP" 5432

kraj
