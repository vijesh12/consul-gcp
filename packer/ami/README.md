# Packer HashiStack AMI

This folder contains the necessary files and configs for creating and storing a HashiCorp product base image to be used for testing within an AWS environment. The following Linux base images have been used and tested:
 
*  Ubuntu 20.04

The following HC Products are installed by default:

* Consul
* Vault
* Nomad
* Envoy
* Consul Template
* Docker

The image is used by the root `consul_primary.tf` and `consul_secondary.tf` modules to configure and run
an ACL, TLS, Connect, and Mesh Gateway bootstrapped cross-region federated Consul Datacenter to be used
for customer reproduction testing and HC Product integration testing.

## Dependencies
1. `aws` CLI must be installed on the base AMI in order for cloud init to properly render
Terraform variables to each Consul VM.
2. Doormat AWS credentials within your current shell session.
3. Git and HashiCorp Support GitHub credential access.

## Packer Image Quick Start

To build the HashiStack AMI:

1. `git clone` this repo to your local machine.
1. Install [Packer](https://www.packer.io/).
1. Configure your AWS credentials using one of the [options supported by the AWS
   SDK](http://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/credentials.html). Usually, the easiest option is to
   set the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.
1. Update the `variables` section of the `packer/ami/hashistack-ubuntu.pkr.hcl` Packer template to configure the AWS regions and HashiCorp product versions you need.
1. Run `packer build packer/ami/hashistack-ubuntu.pkr.hcl`.

## Packer: Configuring HashiCorp Product Versioning

Set the `hashistack-ubuntu.pkr.hcl` input variables to utilize the AWS Regions and Hashi Product versions you wish to test with.

```hcl
variable "aws_region" {
   type    = string
   default = "us-east-2"
}

variable "aws_copy_regions" {
   type    = list(string)
   default = [
   "us-east-1"
   ]
}

variable "consul_version" {
type    = string
default = "1.15.1+ent"
}

variable "consul_template_version" {
type    = string
default = "0.30.0"
}

variable "nomad_version" {
type    = string
default = "1.5.0+ent"
}

variable "vault_version" {
type    = string
default = "1.13.0+ent"
}

variable "envoy_version" {
type    = string
default = "1.25.1"
}

variable "ubuntu_version" {
type    = string
default = "20.04"
}
```

## Consul RPC TLS Certificate Generation/Update for AMI Image

Please review the README.md contents found within `../tls/tls-init` directory to learn how to re-generate or
update the self-signed Consul TLS Certificates used within the cluster for cross-dc and inter-dc RPC
communications.