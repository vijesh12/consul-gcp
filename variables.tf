variable "project_id" { type = string }
variable "region" {
  type = string
  default = "us-central1"
}
variable "network" {
  type = string
  default = "default"
}
variable "subnetwork" {
  type = string
  default = "default"
}

variable "k8s_version" {
  type = string
  default = "1.30.2-gke.200"
}
# adjust as GA releases roll
variable "node_machine" {
  type = string
  default = "n2-standard-4"
}
variable "node_count" {
  type = number
  default = 3
}

# Node taint keeps app workloads off the Consul-server pool
variable "consul_taint" {
  type    = string
  default = "consul=server:NoSchedule"
}
## ------------------- Client Nodes ------------------- ##
variable "zone" {
  type = string
  default = "us-central1-a"
}
variable "instance_count" {
  type = number
  default = 3
}
variable "instance_max" {
  type = number
  default = 10
}
variable "machine_type" {
  type = string
  default = "n2-standard-2"
}
variable "disk_size_gb" {
  type = number
  default = 30
}

# Image family created by Packer
variable "image_family" {
  type = string
  default = "hashistack-client"
}

# Tags let us apply firewall rules
variable "network_tags" {
  type = list(string)
  default = ["consul-client", "nomad-client"]
}
