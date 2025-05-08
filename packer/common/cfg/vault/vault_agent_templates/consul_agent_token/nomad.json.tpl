{{ with secret "kv/data/nomad/server" }}
{
    "acl": {
        "tokens": {
            "agent":  "{{ .Data.data.consul_secret_id }}",
            "default":  "{{ .Data.data.consul_secret_id }}"
        }
    }
}
{{ end }}