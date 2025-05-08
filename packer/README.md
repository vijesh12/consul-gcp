## NOTE: About [/modules](https://github.com/hashicorp/terraform-aws-consul/tree/master/modules) and [/examples](https://github.com/hashicorp/terraform-aws-consul/tree/master/examples)

HashiCorp's Terraform Registry requires every repo to have a `main.tf` in its root dir. The Consul code is broken down into multiple sub-modules, so they can't all be in the root dir [/](https://github.com/hashicorp/terraform-aws-consul/tree/master). Therefore, Consul's sub-modules are in the [/modules](https://github.com/hashicorp/terraform-aws-consul/tree/master/modules) subdirectory, the example code is in the [/examples](https://github.com/hashicorp/terraform-aws-consul/tree/master/examples) subdirectory, and the root dir [/](https://github.com/hashicorp/terraform-aws-consul/tree/master) _also_ has an example in it, as described in [root-example](https://github.com/awesome/terraform-aws-consul/tree/master/examples/root-example).

More info: https://github.com/hashicorp/terraform-aws-consul/pull/79/files/079e75015a5d89e7ffc89997aa0904e9de4cdb97#r212763365



---

image: registry.connect.redhat.com/hashicorp/consul-enterprise:1.20.1-ent-ubi
imageK8S: registry.connect.redhat.com/hashicorp/consul-k8s-control-plane:1.6.1-ubi
imageConsulDataplane: registry.connect.redhat.com/hashicorp/consul-dataplane:1.6.1-ubi

Fifth-Third Bank Vulnerabilities
* Consul Dataplane (All due by 04/16/25):
  * These are the CVEs that came up -- 
    * CVE-2024-45337 (03/17/25)
    * CVE-2024-3596 (03/17/25)
    * CVE-2024-12797 (04/16/25)
    * CVE-2021-3997 (04/16/25)
    * CVE-2019-12900 (04/16/25) 
    * CVE-2024-2236 (04/16/25) 
    * CVE-2024-26462 (04/16/25)
* Good to hold out until OCP upgrade to 4.18
  * If we release something by end of May, then these ideally won't be an issue, however, if not they need to be resolved by the beginning of July.