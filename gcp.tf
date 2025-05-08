resource "google_service_account" "clients_sa" {
  project      = var.project_id
  account_id   = "hashistack-clients"
  display_name = "Consul & Nomad client nodes"
}

# IAM roles as needed (minimal set shown)
resource "google_project_iam_member" "clients_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.clients_sa.email}"
}

resource "google_project_iam_member" "clients_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.clients_sa.email}"
}

resource "google_compute_instance_template" "consul_nomad_client" {
  name_prefix  = "consul-nomad-client-"
  project      = var.project_id
  region       = var.region

  machine_type = var.machine_type
  tags         = var.network_tags

  disk {
    source_image_family  = var.image_family
    source_image_project = var.project_id
    auto_delete          = true
    boot                 = true
    disk_type            = "pd-balanced"
    disk_size_gb         = var.disk_size_gb
  }

  network_interface {
    network    = var.network
    subnetwork = var.subnetwork
    access_config {}           # one ephemeral public IP per VM; omit if you use NAT
  }

  service_account {
    email  = google_service_account.clients_sa.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Simple TCP check on Consul HTTP port 8500
resource "google_compute_health_check" "consul_tcp" {
  name    = "consul-tcp-8500"
  project = var.project_id

  tcp_health_check {
    port = 8500
  }
  check_interval_sec  = 15
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2
}

resource "google_compute_instance_group_manager" "clients_mig" {
  name               = "consul-nomad-mig"
  project            = var.project_id
  base_instance_name = "consul-nomad"
  zone               = var.zone

  version {
    instance_template  = google_compute_instance_template.consul_nomad_client.id
    name               = "primary"
  }

  target_size        = var.instance_count
  target_pools       = []                         # not using legacy LB

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"            # rolling replace
    max_surge_fixed       = 1
    max_unavailable_fixed = 0
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.consul_tcp.id
    initial_delay_sec = 300
  }
}

# Autoscale by CPU
resource "google_compute_autoscaler" "clients_autoscale" {
  name   = "consul-nomad-autoscaler"
  project = var.project_id
  zone    = var.zone
  target  = google_compute_instance_group_manager.clients_mig.id

  autoscaling_policy {
    max_replicas    = var.instance_max
    min_replicas    = var.instance_count
    cooldown_period = 120

    cpu_utilization {
      target = 0.6     # scale out above 60 % average CPU
    }
  }
}
