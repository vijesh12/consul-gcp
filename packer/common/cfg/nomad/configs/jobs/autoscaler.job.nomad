job "autoscaler" {
  datacenters = ["dc1"]

  group "autoscaler" {
    count = 1

    task "autoscaler" {
      driver = "docker"

      config {
        image   = "hashicorp/nomad-autoscaler-enterprise:0.3.3"
        command = "nomad-autoscaler"
        args    = ["agent", "-config", "${NOMAD_TASK_DIR}/config.hcl"]
      }

      template {
        data = <<EOF
plugin_dir = "/plugins"

log_level = "trace"

nomad {
  address = "http://{{env "attr.unique.network.ip-address" }}:4646"
}

apm "nomad" {
  driver = "nomad-apm"
  config  = {
    address = "http://{{env "attr.unique.network.ip-address" }}:4646"
  }
}

apm "prometheus" {
  driver = "prometheus"
  config = {
    address = "http://{{ env "attr.unique.network.ip-address" }}:9090"
  }
}

strategy "target-value" {
  driver = "target-value"
}

dynamic_application_sizing {
  evaluate_after = "5m"
  metrics_preload_threshold = "12h"
}
          EOF

        destination = "${NOMAD_TASK_DIR}/config.hcl"
      }
    }
  }
}