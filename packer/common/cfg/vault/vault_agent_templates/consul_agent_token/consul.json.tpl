{{ with secret "consul/creds/consul-server" }}
{
    "acl": {
        "tokens": {
            "agent":  "{{ .Data.token }}",
            "default":  "{{ .Data.token }}"
        }
    }
}
{{ end }}