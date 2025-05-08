{
  "consul": {
    {{ with secret "kv/data/nomad/server" }}
    "token": "{{ .Data.data.consul_secret_id }}"
    {{ end }}
  }
}