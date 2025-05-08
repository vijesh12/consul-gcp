## Consul RPC TLS Certificate Generation/Update for AMI Image

The contents of the tls/tls-init directory will aid in generating self-signed certificates
to be used for Consul RPC internal and cross-datacenter communication. The `ssl-create.sh`
script uses Consul's built in CA and CLI commands to generate server and client certs to 
issue and render via the `modules/tls.tf` and `modules/asg/userdata.tf` Terraform modules.

### Generate TLS Certificates

* Run local Consul client dev agent on local machine

```shell-interactive
consul agent -dev -node localhost
```

* (Optional) Modify the validity period if desired of your certificates within the `ssl-create.sh` script

```shell-interactive
FIVE_YEARS=$(( 24 * 365 * 5 ))
CERT_VALIDITY=${CERT_VALIDITY:=${FIVE_YEARS}} # Default certificate validity in days => 5 yrs
```

* Modify the DC1 and DC2 variables of the `ssl.create.sh` script to match your AWS regions

```shell-interactive
DC1="us-east-2"
DC2="us-east-1"
```

* Change current directory to `packer/tls/tls-init/` and run:

```shell-interactive
./ssl-create.sh
```

* Monitor script for proper execution and verification of cert validity.

The script will transfer the `ca.pem`, `ca-key.pem`, `server.pem`, and `server-key.pem` certs
to the `packer/common/cfg/tls` directory to be ingested by the Packer AMI image during the image
build process.