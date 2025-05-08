#!/bin/bash

FIVE_YEARS=$(( 24 * 365 * 5 ))
CERT_VALIDITY=${CERT_VALIDITY:=${FIVE_YEARS}} # Default certificate validity in days => 5 yrs
DC1="us-east-2"
DC2="us-east-1"

# Clear old certificate data
echo "[-] Clearing old CA and Certificate Data"
sudo rm -rf ca/* certs/* keys/* req/* ./*.pem
sudo rm -f ../../common/cfg/tls/ca.pem
sudo rm -f ../../common/cfg/tls/ca-key.pem
sudo rm -f ../../common/cfg/tls/server.pem
sudo rm -f ../../common/cfg/tls/server-key.pem
sleep 1

# Recreate necessary directories
mkdir -p ca certs keys req ../../common/cfg/tls

echo "[+] Initializing Consul Connect CA"
consul tls ca create -common-name "Consul Agent CA" -days=$(( 365 * 5 )) -domain consul

echo "[+] Copying Connect CA Certs -> ca/ca.pem | ca/ca-key.pem"
[[ -f consul-agent-ca.pem ]] || { echo "Missing consul-agent-ca.pem"; exit 1; }
[[ -f consul-agent-ca-key.pem ]] || { echo "Missing consul-agent-ca-key.pem"; exit 1; }
sudo cp -f consul-agent-ca.pem ca/ca.pem
sudo cp -f consul-agent-ca-key.pem ca/ca-key.pem

echo "[+] Generating Consul Server x509 Certificate using ca/consul-agent-ca-key.pem --> certs/server.pem"
consul tls cert create -server -dc="$DC1" \
  -additional-dnsname="server.$DC2.consul" \
  -additional-dnsname="*.server.$DC1.consul" \
  -additional-dnsname="*.server.$DC2.consul" \
  -additional-dnsname="*.$DC1.consul" \
  -additional-dnsname="*.$DC2.consul" \
  -additional-dnsname="*.consul-support.services" \
  -additional-dnsname="*.consul.consul-support.services" \
  -additional-dnsname="*.server.$DC1.consul.consul-support.services" \
  -additional-dnsname="*.server.$DC2.consul.consul-support.services" \
  -additional-dnsname="*.$DC1.elb.amazonaws.com" \
  -additional-dnsname="*.$DC2.elb.amazonaws.com" \
  -additional-ipaddress="127.0.0.1" \
  -additional-ipaddress="127.0.1.1" \
  -additional-ipaddress="10.0.0.0" \
  -additional-ipaddress="20.0.0.0"

echo "[+] Copying Server Certificate and Key"
CERT_FILE="${DC1}-server-consul-0.pem"
KEY_FILE="${DC1}-server-consul-0-key.pem"

[[ -f $CERT_FILE ]] || { echo "Missing $CERT_FILE"; exit 1; }
[[ -f $KEY_FILE ]] || { echo "Missing $KEY_FILE"; exit 1; }

sudo cp -f "$CERT_FILE" certs/server.pem
sudo cp -f "$KEY_FILE" keys/server-key.pem

echo "[+] Copying Consul CA and Server Certificates and Keys to root TLS directory"
sudo cp -f ca/ca.pem ../../common/cfg/tls/ca.pem
sudo cp -f ca/ca-key.pem ../../common/cfg/tls/ca-key.pem
sudo cp -f certs/server.pem ../../common/cfg/tls/server.pem
sudo cp -f keys/server-key.pem ../../common/cfg/tls/server-key.pem
sudo chmod 0755 ../../common/cfg/tls/*

sleep 1
echo "[+] Validate SAN IPs and DNS SANs below"

if [[ "$(openssl x509 -pubkey -in ../../common/cfg/tls/server.pem -noout | openssl md5)" == "$(openssl pkey -pubout -in ../../common/cfg/tls/server-key.pem | openssl md5)" ]]; then
  echo "[*] server.pem validation successful (/packer/common/cfg/tls/server.pem)!"
else
  echo "[-] Certificate validation failed (server.pem)!"
  exit 1
fi

if [[ "$(openssl x509 -pubkey -in ../../common/cfg/tls/ca.pem -noout | openssl md5)" == "$(openssl pkey -pubout -in ../../common/cfg/tls/ca-key.pem | openssl md5)" ]]; then
  echo "[*] ca.pem validation successful (/packer/common/cfg/tls/ca.pem)!"
  echo "[+] Verify certificate details below:"
  openssl x509 -text -noout -in ../../common/cfg/tls/server.pem
else
  echo "[-] Certificate validation failed (ca.pem)!"
  exit 1
fi

echo "**** Done!"
