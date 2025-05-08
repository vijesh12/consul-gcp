{{ with secret "kv/data/nomad/client" }}
{
    "acl": {
        "tokens": {
            "agent":  "{{ .Data.data.consul_secret_id }}",
            "default":  "{{ .Data.data.consul_secret_id }}"
        }
    }
}
{{ end }}