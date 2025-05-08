# $ cat ig-http.nomad

job "ig-http" {

  datacenters = ["us-east-2"]

  group "ingress-group" {

    network {
      mode = "bridge"
      port "inbound" {
        static = 8080
        to     = 8080
      }
    }

    service {
      name = "my-ingress-service"
      port = "8080"

      connect {
        gateway {
          proxy {
            connect_timeout = "500ms"
          }
          ingress {
            listener {
              port     = 8080
              protocol = "http"
              service {
                name = "uuid-api"
                hosts = ["localhost:8080"]
              }
            }
          }
        }
      }
    }
  }

  group "generator" {
    network {
      mode = "host"
      port "api" {}
    }

    service {
      name = "uuid-api"
      port = "${NOMAD_PORT_api}"

      connect {
        native = true
      }
    }

    task "generate" {
      driver = "docker"

      config {
        image        = "hashicorpnomad/uuid-api:v3"
        network_mode = "host"
      }

      env {
        BIND = "0.0.0.0"
        PORT = "${NOMAD_PORT_api}"
      }
    }
  }
}