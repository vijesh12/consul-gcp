# variable "nomad_token" {
#   type = string
# }

job "prometheus" {
#   region      = "az-us"
#   datacenters = ["us-west-2"]
  datacenters = ["dc1"]

#   constraint {
#     attribute = attr.kernel.name
#     value     = "linux"
#   }

#   constraint {
#     attribute = node.class
#     value     = "spot"
#   }

  group "autoscaler" {
    count = 1


    network {
      mode = "bridge"
    }

    service {
      name = "autoscaler"

      connect {
        sidecar_service {
          proxy {
            upstreams {
              destination_name = "prometheus"
              local_bind_port  = 6789
            }
          }
        }
      }
    }

    task "autoscaler" {
      driver = "docker"

      config {
        image   = "hashicorp/nomad-autoscaler-enterprise:0.3.3"
        command = "nomad-autoscaler"
        args    = ["agent", "-config", "$${NOMAD_TASK_DIR}/config.hcl"]
      }

      template {
        data = <<EOF
plugin_dir = "/plugins"

log_level = "trace"

nomad {
  address = "http://{{env "attr.unique.network.ip-address" }}:4646"
}

apm "nomad-apm" {
  driver = "nomad-apm"
}

apm "prometheus" {
  driver = "prometheus"
  config = {
    address = "http://{{ env "NOMAD_UPSTREAM_ADDR_prometheus" }}"
  }
}

dynamic_application_sizing {
  evaluate_after = "5m"
  metrics_preload_threshold = "3m"
}

strategy "target-value" {
  driver = "target-value"
}
          EOF

        destination = "$${NOMAD_TASK_DIR}/config.hcl"
      }
    }
  }

  group "prometheus" {
    count = 1

    network {
      mode = "bridge"
    }


    service {
      port = 9090
      name = "prometheus"
      connect {
        sidecar_service {}
      }

      # check {
      #   type     = "http"
      #   path     = "/-/healthy"
      #   interval = "10s"
      #   timeout  = "2s"
      # }

    }

    task "prometheus" {
      driver = "docker"

      config {
        image = "prom/prometheus:v2.29.1"

        args = [
          "--config.file=/etc/prometheus/config/prometheus.yml",
          "--storage.tsdb.path=/prometheus",
          "--web.console.libraries=/usr/share/prometheus/console_libraries",
          "--web.console.templates=/usr/share/prometheus/consoles",
        ]

        volumes = [
          "local/config:/etc/prometheus/config",
        ]
      }

      template {
        data = <<EOH
---
global:
  scrape_interval:     1s
  evaluation_interval: 1s

scrape_configs:
  - job_name: nomad
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']
    static_configs:
    - targets: ['{{ env "attr.unique.network.ip-address" }}:4646']

  - job_name: consul
    metrics_path: /v1/agent/metrics
    params:
      format: ['prometheus']
    static_configs:
    - targets: ['{{ env "attr.unique.network.ip-address" }}:8500']
EOH

        change_mode   = "signal"
        change_signal = "SIGHUP"
        destination   = "local/config/prometheus.yml"
      }

      resources {
        cpu    = 100
        memory = 256
      }
    }
  }
}
