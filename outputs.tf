output "cluster_name"     { value = google_container_cluster.consul_regional.name }
output "region"           { value = var.region }
output "kubeconfig_cmd" {
  value = "gcloud container clusters get-credentials ${google_container_cluster.consul_regional.name} --region ${var.region} --project ${var.project_id}"
}
output "mig_name"        { value = google_compute_instance_group_manager.clients_mig.name }
output "template_name"   { value = google_compute_instance_template.consul_nomad_client.name }
output "service_account" { value = google_service_account.clients_sa.email }
