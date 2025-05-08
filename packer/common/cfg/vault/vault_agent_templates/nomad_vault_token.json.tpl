{
  "vault": {
    {{ with secret "auth/token/create/nomad-server" "orphan=true" }}
    "token": "{{ .Auth.ClientToken }}"
    {{ end }}
  }
}