resource "google_service_account" "consul_nodes" {
  account_id   = "consul-nodes"
  description  = "SA for Consul server node pool"
}

resource "google_container_node_pool" "consul_servers" {
  name       = "consul-servers"
  cluster    = google_container_cluster.consul_regional.name
  location   = var.region

  node_count = var.node_count
  node_config {
    machine_type = var.node_machine
    preemptible  = false
    metadata = {
      enable-oslogin = "TRUE"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    service_account = google_service_account.consul_nodes.email

    labels = {
      role = "consul-server"
    }
    tags = ["consul-server"]
    taint {
      key    = split(":", var.consul_taint)[0]
      value  = split(":", var.consul_taint)[1]
      effect = "NO_SCHEDULE"
    }
    disk_type    = "pd-balanced"
    disk_size_gb = 100
  }

  upgrade_settings {
    strategy = "SURGE"          # zero-downtime upgrades
    max_surge       = 1
    max_unavailable = 0
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
