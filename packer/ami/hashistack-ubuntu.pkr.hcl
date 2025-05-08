###############################################################################
# hashistack-gcp.pkr.hcl
#
# Builds a GCE image with:
#   • Consul (client) ${var.consul_version}
#   • Nomad (client)  ${var.nomad_version}
#   • Systemd units & base configs ready to join a
#     consul-k8s server cluster running on GKE
###############################################################################

packer {
  required_plugins {
    googlecompute = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/googlecompute"
    }
  }
  required_version = ">= 1.10.0"
}

###############################################################################
# VARIABLES
# Instance Type: n2-standard-16 (16 vCPU, 64 GB Memory)
###############################################################################
variable "gcp_project_id"       {
  type = string
}
variable "gcp_zone"             {
  type = string
  default = "us-east1-a"
}
variable "image_family"         {
  type = string
  default = "ubuntu-2204-lts"
}
variable "machine_type"         {
  type = string
  default = "n2-standard-16"
}
variable "disk_size"            {
  type = number
  default = 30
}
variable "consul_version"       {
  type = string
  default = "1.15.3+ent"
}
variable "consul_template_version" {
  type    = string
  default = "0.40.0"
}
variable "envoy_version" {
  type    = string
  default = "1.29.12"
}
variable "envconsul_version" {
  type    = string
  default = "0.13.3"
}
variable "nomad_version"        {
  type = string
  default = "1.8.6+ent"
}
variable "vault_version"        {
  type = string
  default = "1.15.16+ent"
}
variable "fake_version" {
  description = "Nicholas Jackson's fake service"
  type        = string
  default     = "0.26.2"
}

###############################################################################
# IMAGE BUILDER
###############################################################################
source "googlecompute" "consul_nomad_client" {
  project_id           = var.gcp_project_id
  zone                 = var.gcp_zone
  source_image_family  = var.image_family
  ssh_username         = "ubuntu"
  disk_size            = var.disk_size
  machine_type         = var.machine_type

  image_name           = "hashistack-client-{{timestamp}}"
  image_family         = "hashistack-client"

  # Optional: encrypt with CMEK / shielded-vm
  # shielded_vm         = true
}

###############################################################################
# PROVISIONERS
###############################################################################
build {
  sources = ["source.googlecompute.consul_nomad_client"]

  provisioner "shell" {
    inline = [
      "mkdir --parents /tmp/packer_files",
      "mkdir --parents /home/ubuntu/logging",
    ]
  }

  provisioner "file" {
    source      = "${path.root}/../common/"
    destination = "/tmp/packer_files/"
  }

  provisioner "file" {
    source      = "${path.root}/../common/scripts/logging/"
    destination = "/home/ubuntu/logging/"
  }

  provisioner "shell" {
    execute_command = "sudo {{ .Vars }} {{ .Path }}"

    scripts = [
      "${path.root}/../common/scripts/configure-update-apt/configure-update-apt.sh",
      "${path.root}/../common/scripts/setup-systemd-resolved/setup-systemd-resolved.sh",
      "${path.root}/../common/scripts/install-consul/install-consul.sh",
      "${path.root}/../common/scripts/install-envoy/install-envoy.sh",
      "${path.root}/../common/scripts/install-envconsul/install-envconsul.sh",
      "${path.root}/../common/scripts/install-datadog/install-datadog.sh",
      "${path.root}/../common/scripts/install-consul-template/install-consul-template.sh",
      "${path.root}/../common/scripts/install-fake-service/install-fake-service.sh",
      "${path.root}/../common/scripts/install-vault/install-vault.sh",
      "${path.root}/../common/scripts/install-nomad/install-nomad.sh",
    ]

    environment_vars = [
      "CONSUL_VERSION=${var.consul_version}",
      "CONSUL_TEMPLATE_VERSION=${var.consul_template_version}",
      "ENVCONSUL_VERSION=${var.envconsul_version}",
      "ENVOY_VERSION=${var.envoy_version}",
      "NOMAD_VERSION=${var.nomad_version}",
      "VAULT_VERSION=${var.vault_version}",
      "FAKE_VERSION=${var.fake_version}",
    ]
  }
}

###############################################################################
# HOW TO BUILD
###############################################################################
# 1. Authenticate:
#    gcloud auth application-default login
#    export GOOGLE_PROJECT_ID=<your-project>
#
# 2. Initialize & build:
#    packer init  .
#    packer build -var 'gcp_project_id=$GOOGLE_PROJECT_ID' \
#                 -var 'gke_consul_host=consul-server.consul.svc.cluster.local' \
#                 hashistack-gcp.pkr.hcl
