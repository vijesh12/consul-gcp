#!/bin/bash

FIVE_YEARS=$(( 24 * 365 * 5 ))
CERT_VALIDITY=${CERT_VALIDITY:=${FIVE_YEARS}} # Default certificate validity in days => 5 yrs
DC1="us-east-2"
DC2="us-east-1"

certDir=/tmp/consul-tls-rotate

sudo mkdir --parents --mode=0755 \
  "${certDir}" \
  "${certDir}/ca" \
  "${certDir}/certs" \
  "${certDir}/keys" \
  ;

echo "[+] Copying Connect CA Certs -> ca/ca.pem | ca/ca-key.pem"
sudo cp /etc/consul.d/tls/consul-agent-ca.pem "${certDir}"/ca/consul-agent-ca.pem
sudo cp /etc/cosnul.d/tls/consul-agent-ca-key.pem "${certDir}"/ca/consul-agent-ca-key.pem

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
  -additional-ipaddress="127.0.0.1" \
  -additional-ipaddress="127.0.1.1" \
  -additional-ipaddress="10.0.0.0" \
  -additional-ipaddress="10.1.0.0"

echo "[+] Copying Connect CA Certs -> ca/ca.pem | ca/ca-key.pem"
sudo cp "$DC1-server-consul-0.pem" "${certDir}"/certs/consul.pem
sudo cp "$DC1-server-consul-0-key.pem" "${certDir}"/keys/consul-key.pem


scp -A "${DC1}-server-consul-0-key.pem" ubuntu@ip-10-0-16-26.us-east-2.compute.internal:/etc/consul.d/tls
#sudo chmod 400 certs/server.pem

echo "[+] Copying Consul CA and Server Certificates and Keys to root TLS directory"
sudo cp "${certDir}"/ca/consul-agent-ca.pem /etc/consul.d/tls
sudo cp "${certDir}"/ca/consul-agent-ca-key.pem /etc/consul.d/tls
sudo cp "${certDir}"/certs/consul.pem /etc/consul.d/tls
sudo cp "${certDir}"/keys/consul-key.pem /etc/consul.d/tls
sudo chmod 0755 /etc/consul.d/tls --recursive /etc/consul.d/tls
sleep 1

echo "[+] Validate SAN IPs and DNS SANs below"
if [[ "$( openssl x509 -pubkey -in ../../common/cfg/tls/server.pem -noout | openssl md5 )" == "$( openssl pkey -pubout -in ../../common/cfg/tls/server-key.pem | openssl md5 )" ]]; then
  echo "[*] server.pem validation successful (/packer/common/cfg/tls/server.pem)!";
else
  clear
  echo "[-] Certificate validation failed (server.pem)!"
  exit 1
fi
if [[ "$( openssl x509 -pubkey -in ../../common/cfg/tls/ca.pem -noout | openssl md5 )" == "$( openssl pkey -pubout -in ../../common/cfg/tls/ca-key.pem | openssl md5 )" ]]; then
  echo "[*] ca.pem validation successful (/packer/common/cfg/tls/ca.pem)!";
  echo "[+] Verify certificate details below: "
  openssl x509 -text -noout -in ../../common/cfg/tls/server.pem
else
  clear
  echo "[-] Certificate validation failed (ca.pem)!"
  exit 1
fi
echo "**** Done!"

