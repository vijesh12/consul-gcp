Kind           = "service-resolver"
Name           = "socat"
ConnectTimeout = "15s"
Failover = {
  "*" = {
    Datacenters = ["us-east-2", "us-east-1"]
  }
}
