{
  "consul": {
    {{ with secret "kv/data/nomad/client" }}
    "token": "{{ .Data.data.consul_secret_id }}"
    {{ end }}
  }
}