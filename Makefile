# Troslojna aplikacija kao kod: jedna komanda gradi cijelo okruženje.
# Recepti počinju znakom ">" a ne tabulatorom, da kopiranje ne pokvari fajl.
.RECIPEPREFIX = >
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.PHONY: help check infra config dns test all destroy clean

help:
> @echo "make check    - provjeri da su svi alati tu"
> @echo "make infra    - Terraform: napravi dvije VM (app, dns)"
> @echo "make config   - Ansible: Docker, aplikacija, BIND"
> @echo "make dns      - Terraform: zapisi u DNS zoni"
> @echo "make test     - testovi: aplikacija, izolacija, DNS, drift, trajnost"
> @echo "make all      - sve redom (check, infra, config, dns, test)"
> @echo "make destroy  - sruši VM-ove (vault ostaje)"
> @echo "make clean    - sruši sve i obriši tajne (prava gradnja od nule)"

check:
> @for t in terraform ansible-playbook ansible-vault virsh dig nsupdate ssh curl; do \
>   command -v $$t >/dev/null || { echo "FALI alat: $$t"; exit 1; }; \
> done
> @test -e /dev/kvm || { echo "FALI /dev/kvm"; exit 1; }
> @virsh -c qemu:///system list >/dev/null || { echo "libvirt nije dostupan"; exit 1; }
> @echo "check: sve je na broju"

infra:
> scripts/vm-start.sh
> terraform -chdir=terraform/vm init -input=false
> terraform -chdir=terraform/vm apply -auto-approve

config:
> cd ansible && ./vault-init.sh && ansible-playbook site.yml

dns:
> terraform -chdir=terraform/dns init -input=false
> S=$$(ansible/tsig-secret.sh) && TF_VAR_tsig_secret="$$S" terraform -chdir=terraform/dns apply -auto-approve

all: check infra config dns test

destroy:
> rm -f terraform/dns/terraform.tfstate terraform/dns/terraform.tfstate.backup
> terraform -chdir=terraform/vm destroy -auto-approve

clean: destroy
> rm -f ansible/.vault_pass ansible/group_vars/all/vault.yml ansible/group_vars/dns_servers/vault.yml ansible/inventory.ini

test:
> tests/app.sh
> tests/izolacija.sh
> tests/dns.sh
> tests/trajnost.sh
> tests/drift.sh
