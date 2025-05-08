service {
  name = "backend"
  id   = "backend-1"
  port = 8080

  connect {
    sidecar_service {
      port = 20000
      proxy = {
        config = {
          envoy_prometheus_bind_addr  = "127.0.0.1:9105"
          envoy_stats_bind_addr       = "127.0.0.1:9106"
          envoy_tracing_json          = "{\"http\":{\"typedConfig\":{\"@type\": \"type.googleapis.com/envoy.config.trace.v3.DatadogConfig\", \"collector_cluster\":\"datadog_8126\",\"service_name\":\"backend-1-sidecar-proxy\"},\"name\":\"envoy.tracers.datadog\"}}"
        }
      }
    }
  }
  checks = [{
      name     = "backend-health"
      http     = "http://127.0.0.1:8080/health"
      interval = "30s"
      timeout  = "5s"
    },{
      name     = "backend-ready"
      http     = "http://127.0.0.1:8080/ready"
      interval = "30s"
      timeout  = "5s"
    }]
}