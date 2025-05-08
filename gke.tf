resource "google_container_cluster" "consul_regional" {
  name     = "consul-cluster"
  location = var.region           # regional control plane
  network  = var.network
  subnetwork = var.subnetwork

  release_channel { channel = "REGULAR" }      # keeps cluster patched
  min_master_version = var.k8s_version

  # Workload Identity lets Consul pods access GCS/GSM without node service-account keys
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  ip_allocation_policy {                       # VPC-native / Alias IP
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  networking_mode = "VPC_NATIVE"
  enable_l4_ilb_subsetting = true              # nice for mesh gateways
}
