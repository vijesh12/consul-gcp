job "example_reactjs_acc" {
#   region      = "az-us"
#   datacenters = ["us-west-2"]
  datacenters = ["dc1"]
  type        = "service"

#   constraint {
#     attribute = attr.kernel.name
#     value     = "linux"
#   }

#   constraint {
#     attribute = node.class
#     value     = "spot"
#   }

  group "reactjs_example-acc" {
    count = 1
    network {
    #   port "http" { to = 8080 } # Defined in the Dockerfile expose port
      port "db" { to = 6379 }
    }

    scaling {
      enabled = true
      min     = 1
      max     = 3

      policy {
        cooldown            = "1m"
        evaluation_interval = "1m"

        check "cpu_allocated_percentage" {
          source = "prometheus"
          query  = "sum(nomad_client_allocated_cpu*100/(nomad_client_unallocated_cpu+nomad_client_allocated_cpu))/count(nomad_client_allocated_cpu)"

          strategy "target-value" {
            target = 70
          }
        }

        check "mem_allocated_percentage" {
          source = "prometheus"
          query  = "sum(nomad_client_allocated_memory*100/(nomad_client_unallocated_memory+nomad_client_allocated_memory))/count(nomad_client_allocated_memory)"

          strategy "target-value" {
            target = 70
          }
        }
      }
    }

    service {
      name = "reactjs-example-acc"
      port = "db"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.reactjs-example-acc.rule=Host(`reactjs-example-acc.bmgf.io`)", # Change this to the hostname of your app and env
        "traefik.http.routers.reactjs-example-acc.entrypoints=https",
        "traefik.http.routers.reactjs-example-acc.tls=true"
      ]
    }

    task "reactjs_example_acc" {
      driver = "docker"

      config {
        # image = "bmgfsre.azurecr.io/example-reactjs-app:latest" # Change this to be the ACR location and repo for your app, with either latest or named tag
        image = "redis:3.2"
        ports = ["db"]
      }

      scaling "cpu" {
        policy {
          cooldown            = "1m"
          evaluation_interval = "1m"

          check "95pct" {
            strategy "app-sizing-percentile" {
              percentile = "95"
            }
          }
        }
      }

      scaling "mem" {
        enabled = true
        policy {
          cooldown            = "1m"
          evaluation_interval = "1m"

          check "max" {
            strategy "app-sizing-max" {}
          }
        }
      }

      resources {
        cpu    = 128
        memory = 128
      }
    }
  }
}
