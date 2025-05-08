variable "image_version" {
  type = string
  description = "redis image version"
  default = "3.1"
}

job "example" {
  datacenters = ["dc1"]
  group "cache" {
    network {
      port "db" {
        to = 6379
      }
    }

    task "redis" {
      driver = "docker"
      config {
        image = "redis:${var.image_version}"
        ports = ["db"]
      }
    }
  }
}
