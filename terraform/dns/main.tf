# Zapisi u zoni projekat.lab kao Terraform resursi. Provider hashicorp/dns šalje izmjene na BIND
# (dns VM) protokolom RFC 2136, potpisane TSIG ključem ruo-tf, koji smije mijenjati samo ovu zonu.

terraform {
  required_version = ">= 1.5"
  required_providers {
    dns = { source = "hashicorp/dns", version = "~> 3.4" }
  }
}

variable "tsig_secret" {
  description = "TSIG tajna ključa ruo-tf (dolazi iz ansible-vault, nikad iz Gita)"
  type        = string
  sensitive   = true
}

variable "zona" {
  type    = string
  default = "projekat.lab."
}

# adrese VM-ova čitamo iz stanja prvog Terraforma (terraform/vm), pa ih nigdje ne upisujemo ručno
data "terraform_remote_state" "vm" {
  backend = "local"
  config = {
    path = "${path.module}/../vm/terraform.tfstate"
  }
}

locals {
  ip = data.terraform_remote_state.vm.outputs.ip
}

provider "dns" {
  update {
    server        = local.ip["dns"]
    key_name      = "ruo-tf."
    key_algorithm = "hmac-sha256"
    key_secret    = var.tsig_secret
  }
}

resource "dns_a_record_set" "app" {
  zone      = var.zona
  name      = "app"
  addresses = [local.ip["app"]]
  ttl       = 300
}

resource "dns_cname_record" "web" {
  zone  = var.zona
  name  = "web"
  cname = "app.${var.zona}"
  ttl   = 300
}

resource "dns_txt_record_set" "vlasnik" {
  zone = var.zona
  txt  = ["upravlja: terraform"]
  ttl  = 300
}

output "imena" {
  value = ["app.${var.zona}", "web.${var.zona}"]
}
