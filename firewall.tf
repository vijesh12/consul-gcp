# Allow Consul & Nomad traffic **inside** the VPC
resource "google_compute_firewall" "consul_nomad_internal" {
  project = var.project_id
  name    = "allow-consul-nomad-internal"
  network = var.network
  priority = 1000

  direction = "INGRESS"
  source_tags = var.network_tags            # traffic coming from other clients
  target_tags = var.network_tags

  allow {
    protocol = "tcp"
    ports = [
      "4646-4648",  # Nomad HTTP / RPC / Serf
      "8300-8302",  # Consul RPC / LAN Serf / WAN Serf
      "8500",       # Consul HTTP
      "8600"        # Consul DNS (TCP)
    ]
  }

  allow {
    protocol = "udp"
    ports = ["8600"]   # Consul DNS (UDP)
  }
}

# Access **from** the GKE node CIDR (Consul servers) to the clients
# Replace with the real node CIDR from your cluster
resource "google_compute_firewall" "gke_to_clients" {
  project = var.project_id
  name    = "allow-gke-to-consul-clients"
  network = var.network
  priority = 1000

  direction = "INGRESS"
  source_ranges = ["10.0.0.0/14"]     # Example GKE node range
  target_tags   = var.network_tags

  allow {
    protocol = "tcp"
    ports    = ["8300-8302", "8500", "8600"]
  }
  allow {
    protocol = "udp"
    ports    = ["8600"]
  }
}
