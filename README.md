# Troslojna aplikacija kao kod

## Šta je u projektu

Aplikacija je brojač posjeta: pregledač traži stranicu od Nginxa, stranica poziva API, API upisuje posjetu
u PostgreSQL i vraća ukupan broj. Time prolazi kroz sva tri sloja.

```
Windows 11
└─ WSL2 (Ubuntu): Terraform, Ansible, make, testovi
   └─ KVM/libvirt, mreža "default" 192.168.122.0/24 (NAT, DHCP)
      ├─ VM app  (Ubuntu 24.04, 2 vCPU, 2 GB RAM, 20 GB disk)
      │   └─ Docker Compose, projekat "ruo"
      │       ├─ frontend  Nginx       mreže: web, app    jedini objavljen port: 80
      │       ├─ backend   Flask       mreže: app, db
      │       └─ db        PostgreSQL  mreža: db          imenovani volumen ruo_dbdata
      └─ VM dns  (Ubuntu 24.04, 1 vCPU, 1 GB RAM, 10 GB disk)
          └─ BIND9, zona projekat.lab (zapise upisuje Terraform, potpisano TSIG ključem)

Tok zahtjeva:  pregledač → app VM :80 → frontend → backend:8000 → db:5432
```

## Plan adresa

| Mreža | Adresni prostor | Ko je u njoj | Napomena |
|---|---|---|---|
| libvirt `default` | 192.168.122.0/24 | VM `app`, VM `dns` | DHCP; adrese se ne upisuju u kod, čitaju se iz Terraform stanja |
| Docker `web` | 10.40.1.0/24 | frontend | jedina mreža s izlazom prema vani |
| Docker `app` | 10.40.2.0/24 | frontend, backend | `internal: true` |
| Docker `db` | 10.40.3.0/24 | backend, db | `internal: true` |

Imena u DNS zoni `projekat.lab`: `ns1` (dns VM), `app` (A zapis na app VM), `web` (CNAME na `app`), TXT zapis vlasnika.

## Struktura repozitorija

| Putanja | Sadržaj |
|---|---|
| `Makefile` | dugmad: `check`, `infra`, `config`, `dns`, `test`, `all`, `destroy`, `clean` |
| `terraform/vm/` | dvije VM (libvirt, Ubuntu cloud slika, cloud-init) i generisani Ansible inventar |
| `cloud-init/` | šablon korisničkih podataka (korisnik `student`, samo SSH ključ) |
| `ansible/` | `site.yml`, `sat.yml`, role `docker`, `app`, `dns`, `vault-init.sh`, `tsig-secret.sh` |
| `terraform/dns/` | A, CNAME i TXT zapisi u zoni (provider `hashicorp/dns`, RFC 2136 + TSIG) |
| `app/` | Flask backend, Nginx frontend, `compose.yaml` |
| `tests/` | provjere: aplikacija, izolacija mreže, DNS, drift, trajnost podataka |
| `scripts/vm-start.sh` | pali ugašene VM (npr. poslije restarta WSL-a) |
| `docs/` | snimljeni izlazi probe od nule, drugog pokretanja i testova |

## Preduslovi

Windows 11 sa WSL2 (Ubuntu) i uključenom virtualizacijom. U Ubuntuu: KVM (`/dev/kvm`), libvirt, Terraform,
Ansible, `dig` i `nsupdate` (paket `bind9-dnsutils`), te SSH ključ `~/.ssh/id_ed25519`.
Provjera: `make check`.

## Pokretanje od nule

```bash
git clone https://github.com/sarchyy/ruo-projekat.git ruo-projekat
cd ruo-projekat
make all        # check, infra, config, dns, test (oko 12 minuta pri prvoj gradnji)
```

Dugmad pojedinačno:

| Komanda | Šta radi |
|---|---|
| `make infra` | Terraform pravi VM `app` i `dns`, cloud-init ih priprema, generiše se `ansible/inventory.ini` |
| `make config` | `vault-init.sh` pravi tajne (samo ako ne postoje), Ansible instalira Docker, pokreće aplikaciju i podešava BIND |
| `make dns` | Terraform upisuje zapise u zonu `projekat.lab` |
| `make test` | pokreće sve testove iz `tests/` |
| `make destroy` | ruši VM (tajne ostaju) |
| `make clean` | ruši sve i briše tajne: stanje kao na čistoj mašini |

Rušenje i ponovna gradnja: `make clean && make all`.

## Tajne

- `ansible/vault-init.sh` pri prvom pokretanju nasumično pravi lozinku baze i TSIG ključ i šifruje ih ansible-vaultom.
  Lozinka vaulta (`ansible/.vault_pass`) je takođe nasumična. Ništa od toga nije u Gitu (`.gitignore`); u Gitu je samo
  `vault.yml.example`.
- Na VM-u se `.env` pravi iz šablona, vlasnik root, prava `0600`; zadatak koristi `no_log`.
- Terraform za DNS dobija TSIG tajnu samo preko varijable okruženja (`ansible/tsig-secret.sh`), nikad iz fajla u repozitoriju.
- Pristup VM-ovima: samo SSH ključ (`ssh_pwauth: false`, korisnik `student`).
- Provjereno: tajne se ne pojavljuju u logovima u `docs/`.

## Dokazi ponovljivosti i ispravnosti

- **Gradnja od nule:** `make clean`, pa `make all` je prošao bez greške za 11 min 58 s (`docs/proba-od-nule.txt`).
  VM su dobili druge IP adrese nego prije, a sve je radilo bez ručne izmjene.
- **Idempotentnost:** drugo pokretanje Ansible-a (`docs/drugo-pokretanje.txt`):

  ```
  app : ok=13  changed=0  unreachable=0  failed=0
  dns : ok=11  changed=0  unreachable=0  failed=0
  ```
  Terraform `plan` poslije gradnje javlja `No changes`.
- **Testovi:** 29 provjera (aplikacija 4, izolacija 10, DNS 8, trajnost 2, drift 5), svi prolaze (`docs/testovi.txt`).
- **Drift u DNS-u:** `tests/drift.sh` mijenja zapis `app` ručno (`nsupdate` s ključem, mimo Terraforma).
  `terraform plan -detailed-exitcode` vraća 2 i pokazuje razliku, `apply` vraća zapis, a sljedeći `plan` vraća 0:

  ```
  ~ resource "dns_a_record_set" "app" {
      ~ addresses = [
          - "10.40.2.99",
          + "192.168.122.8",
        ]
  Plan: 0 to add, 1 to change, 0 to destroy.
  ```
- **Zaštita DNS-a:** izmjena zone bez TSIG potpisa je odbijena (`REFUSED`), tuđe domene se ne razrješavaju (`recursion no`).

## Zahtjevi zadatka i gdje su ispunjeni

| Zahtjev | Gdje | Dokaz |
|---|---|---|
| AO-1 aplikacija u kontejnerima | `app/`, `compose.yaml` | `tests/app.sh` |
| AO-10 trajnost podataka | volumen `ruo_dbdata` | `tests/trajnost.sh` |
| AO-3, AO-4 VM i cloud-init | `terraform/vm/`, `cloud-init/` | `make infra`, pristup samo ključem |
| AO-5 konfiguracija (idempotentno) | `ansible/` role | drugo pokretanje `changed=0` |
| AO-9 tajne | `vault-init.sh`, ansible-vault | nema tajni u Gitu ni u logovima |
| AO-6 segmentacija mreže | tri Docker mreže | `tests/izolacija.sh` |
| AO-7 DNS server | rola `dns` (BIND9) | `tests/dns.sh` |
| AO-8 DNS kao kod i drift | `terraform/dns/` | `tests/drift.sh` |
| AO-2 ponovljivost | `Makefile` | `make clean && make all` |

Obrazloženja odluka (ADR) su u priloženom PDF dokumentu.

## Poznata ograničenja i savjeti

- **Sat VM-a.** TSIG potpis i `apt` provjeravaju vrijeme. Poslije uspavljivanja laptopa VM-ovi mogu zakasniti, pa
  `ansible/sat.yml` na početku svakog pokretanja poravnava sat s mašinom koja pokreće Ansible.
- **Restart WSL-a.** VM-ovi se ugase. `make infra` ih pali (`scripts/vm-start.sh`) i čeka adrese; kontejneri se sami podižu.
- **Pregledač u Windowsu ne vidi VM direktno** (mreža postoji samo unutar WSL-a). Pogled kroz tunel:
  `ssh -N -L 8080:localhost:80 student@<ip app VM-a>`, pa `http://localhost:8080`.
- **Izmjena koda aplikacije na već podignutoj VM:** `make config` kopira kod, ali Docker ne pravi novu sliku sam;
  potrebno je i `docker compose --project-directory /opt/ruo up -d --build` na VM-u. Pri gradnji od nule slike se prave same.
- Brojač posjeta raste na svaki poziv `/api/posjete`, pa ga povećavaju i testovi.
