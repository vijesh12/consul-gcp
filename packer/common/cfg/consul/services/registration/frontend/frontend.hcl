service {
  name = "frontend"
  id   = "frontend-1"
  port = 9090

  connect {
    sidecar_service {
      port = 20000
      proxy = {
        config = {
          envoy_prometheus_bind_addr = "127.0.0.1:9105"
          envoy_stats_bind_addr      = "127.0.0.1:9106"
          envoy_tracing_json         = "{\"http\":{\"typedConfig\":{\"@type\": \"type.googleapis.com/envoy.config.trace.v3.DatadogConfig\", \"collector_cluster\":\"datadog_8126\",\"service_name\":\"frontend-1-sidecar-proxy\"},\"name\":\"envoy.tracers.datadog\"}}"
        }
        upstreams = [
          {
            destination_name   = "backend"
            local_bind_address = "127.0.0.1"
            local_bind_port    = 8080
            config = {
              connect_timout_ms  = 15000
              limits = {
                max_connections         = 2000
                max_concurrent_requests = 2000
              }
            }
          }
        ]
      }
    }
  }

  checks = [{
      id       = "frontend-health"
      http     = "http://127.0.0.1:9090/health"
      method   = "GET"
      interval = "30s"
      timeout  = "5s"
      },{
        id       = "frontend-ready"
        http     = "http://127.0.0.1:9090/ready"
        method   = "GET"
        interval = "30s"
        timeout  = "5s"
      },{
      name     = "backend-health"
      http     = "http://127.0.0.1:8080/health"
      interval = "30s"
      timeout  = "5s"
      },{
        name     = "backend-ready"
        http     = "http://127.0.0.1:8080/ready"
        interval = "30s"
        timeout  = "5s"
      }
  ]
}