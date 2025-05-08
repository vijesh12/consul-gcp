job "xmltransformer" {
  datacenters = ["dc1", "dc2"]

  type = "service"

#   constraint {
#       distinct_hosts = true
#   }

#   constraint {
#     attribute = "${attr.unique.hostname}"
#     operator  = "regexp"
#     value     = "(xzur5624dap.zur.swissbank.com|xzur5781dap.zur.swissbank.com)"
#   }

#   spread {
#     attribute = "${node.datacenter}"
#     weight    = 100

#     target "dc1" {
#       percent = 100 
#     }
#     target "dc2" {
#       percent = 0
#     }
#   }

#   affinity {
#       attribute = "${attr.unique.hostname}"
#       operator  = "set_contains_any"
#       value     = "xzur5780dap.zur.swissbank.com"
#       weight    = -100
#   }

  update {
    max_parallel = 1
    min_healthy_time = "10s"
    healthy_deadline = "3m"
    progress_deadline = "10m"
    auto_revert = false
    canary = 0
  }

  migrate {
    max_parallel = 1
    health_check = "checks"
    min_healthy_time = "10s"
    healthy_deadline = "5m"
  }

  group "xmltransformer_group" {
    count = 2

    network {
      port "db" {
        to = 6379
      }
    }

    restart {
      attempts = 3
      interval = "30m"
      delay = "15s"
      mode = "delay"
    }

    # ephemeral_disk {
    #   migrate = false
    #   size    = 1000
    #   sticky  = false
    # }

    task "xmltransformer_task" {
      driver = "docker"
    #   user = "24348:20600"

    #   template {
    #     data = <<EOH
    #       {{ if ne (env "meta.REGION") "" }}REGION = {{ env "meta.REGION" }}{{ end }}
    #       {{ if ne (env "meta.APP_ZONE") "" }}APP_ZONE = {{ env "meta.APP_ZONE" }}{{ end }}
    #       {{ if ne (env "meta.APP_Network") "" }}APP_Network = {{ env "meta.APP_Network" }}{{ end }}
    #       {{ if ne (env "meta.MULTICAST_SUBNET") "" }}MULTICAST_SUBNET = {{ env "meta.MULTICAST_SUBNET" }}{{ end }}
    #       {{ if ne (env "meta.MULTICAST_INTERFACE") "" }}MULTICAST_INTERFACE = {{ env "meta.MULTICAST_INTERFACE" }}{{ end }}
    #       {{ if ne (env "meta.MULTICAST_ADDRESS") "" }}MULTICAST_ADDRESS = {{ env "meta.MULTICAST_ADDRESS" }}{{ end }}
    #       {{ if ne (env "meta.PROMETHEUS_URL") "" }}PROMETHEUS_URL = {{ env "meta.PROMETHEUS_URL" }}{{ end }}
    #       {{ if ne (env "meta.PROMETHEUS_SSZ_URL") "" }}PROMETHEUS_SSZ_URL = {{ env "meta.PROMETHEUS_SSZ_URL" }}{{ end }}
    #       {{ if ne (env "meta.PROMETHEUS_RAZ_URL") "" }}PROMETHEUS_RAZ_URL = {{ env "meta.PROMETHEUS_RAZ_URL" }}{{ end }}
    #       {{ if ne (env "meta.PROMETHEUS_OCE_URL") "" }}PROMETHEUS_OCE_URL = {{ env "meta.PROMETHEUS_OCE_URL" }}{{ end }}
    #     EOH

    #     destination = "env.variables"
    #     env = true
    #   }

    #   env {
    #     DEPLOY_ENV = "devint"
    #     STARTUP_PARAMS = "devint_8${NOMAD_ALLOC_INDEX} start -a"
    #     TOMCAT_KEYSTORE = "/app/config/keystores/tomcat.keystore"
    #     KEYSTORE = "/app/config/keystores/techuser.keystore"
    #     TOMCAT_KEYALIAS = "tomcat"
    #     APP_CACHE_DIR = "${NOMAD_ALLOC_DIR}/cache"
    #     APP_DATA_DIR = "${NOMAD_ALLOC_DIR}/data"
    #     APP_LOG_DIR = "${NOMAD_ALLOC_DIR}/logs"
    #     APP_PDATA_DIR = "${NOMAD_ALLOC_DIR}/data"
    #   }

    #   resources {
    #     cpu = 1000
    #     memory = 8000
    #   }

    #   kill_timeout = "20s"
    #   kill_signal = "SIGTERM"

    #   config {
    #     network_mode = "host"
    #     image = "container-registry.ubs.net/ubs/gom/xmltransformer:16.07.07.105328-snapshot"
        
    #     mount {
    #         type = "bind"
    #         target = "/app/config/secrets"
    #         source = "/sbcdata/dyn/data/secrets"
    #         readonly = "true"
    #     } 

    #     mount {
    #         type = "bind"
    #         target = "/app/config/keystores"
    #         source = "/sbcdata/dyn/data/keystores"
    #         readonly = "true"
    #     } 

	# volumes = [
	#     "tmp:/app/state"
    #     ]


    #   }

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

