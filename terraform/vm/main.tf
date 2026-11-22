terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# parametri svake VM-a su varijabla: ime => memorija, procesori, disk
variable "vms" {
  description = "Virtuelne mašine: ime => parametri"
  type = map(object({
    memory_mb = number
    vcpu      = number
    disk_gb   = number
  }))
  default = {
    app = { memory_mb = 2048, vcpu = 2, disk_gb = 20 }
    dns = { memory_mb = 1024, vcpu = 1, disk_gb = 10 }
  }
}

# bazna slika se preuzima jednom, a disk VM-a je njen "copy-on-write" potomak
resource "libvirt_volume" "base" {
  name   = "ubuntu-noble-base.qcow2"
  pool   = "default"
  format = "qcow2"
  source = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

resource "libvirt_volume" "disk" {
  for_each       = var.vms
  name           = "${each.key}.qcow2"
  pool           = "default"
  base_volume_id = libvirt_volume.base.id
  size           = each.value.disk_gb * 1024 * 1024 * 1024
}

resource "libvirt_cloudinit_disk" "init" {
  for_each = var.vms
  name     = "${each.key}-init.iso"
  pool     = "default"
  user_data = templatefile("${path.module}/../../cloud-init/user-data.tftpl", {
    hostname = each.key
    ssh_key  = trimspace(file(pathexpand("~/.ssh/id_ed25519.pub")))
  })
}

resource "libvirt_domain" "vm" {
  for_each  = var.vms
  name      = each.key
  memory    = each.value.memory_mb
  vcpu      = each.value.vcpu
  cloudinit = libvirt_cloudinit_disk.init[each.key].id

  disk { volume_id = libvirt_volume.disk[each.key].id }

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }
}

# adrese obje mašine: { app = "...", dns = "..." }
output "ip" {
  value = { for ime, vm in libvirt_domain.vm : ime => vm.network_interface[0].addresses[0] }
}

resource "local_file" "inventory" {
  filename             = "${path.module}/../../ansible/inventory.ini"
  file_permission      = "0644"
  directory_permission = "0755"
  content              = <<-EOT
    [app_servers]
    app ansible_host=${libvirt_domain.vm["app"].network_interface[0].addresses[0]} ansible_user=student

    [dns_servers]
    dns ansible_host=${libvirt_domain.vm["dns"].network_interface[0].addresses[0]} ansible_user=student
  EOT
}