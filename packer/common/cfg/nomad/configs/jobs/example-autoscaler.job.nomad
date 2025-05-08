job "example" {
  datacenters = ["dc1"]

  group "cache" {
    network {
      port "db" {
        to = 6379
      }
    }

    scaling {
      enabled = true
      min = 1
      max = 3

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

    task "redis" {
      driver = "docker"

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
        policy {
          cooldown            = "1m"
          evaluation_interval = "1m"

          check "max" {
            strategy "app-sizing-max" {}
          }
        }
      }

      config {
        image = "redis:3.2"

        ports = ["db"]
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}
