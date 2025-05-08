Kind = "service-defaults"
Name = "socat"

UpstreamConfig = {
  Defaults = {
    MeshGateway = {
      Mode = "local"
    }
  }

  Overrides = [
    {
      Name = "socat-dc2"
      MeshGateway = {
        Mode = "remote"
      }
    }
  ]
}
