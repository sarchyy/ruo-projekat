#!/usr/bin/env bash
# Ako su VM-ovi ugašeni (npr. poslije restarta WSL-a), upali ih i sačekaj da dobiju IP adresu.
# Pri prvoj gradnji VM-ova još nema pa skripta ne radi ništa.
set -u
V="virsh -c qemu:///system"
for vm in app dns; do
  $V domstate "$vm" 2>/dev/null | grep -q 'shut off' && $V start "$vm"
done
for vm in app dns; do
  $V dominfo "$vm" >/dev/null 2>&1 || continue
  for i in $(seq 1 60); do
    $V domifaddr "$vm" 2>/dev/null | grep -q ipv4 && break
    sleep 2
  done
done
exit 0
