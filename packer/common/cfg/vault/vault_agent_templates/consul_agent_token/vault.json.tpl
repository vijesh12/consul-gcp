{{ with secret "consul/creds/vault-server" }}
{
    "acl": {
        "tokens": {
            "agent":  "{{ .Data.token }}",
            "default":  "{{ .Data.token }}"
        }
    }
}
{{ end }}