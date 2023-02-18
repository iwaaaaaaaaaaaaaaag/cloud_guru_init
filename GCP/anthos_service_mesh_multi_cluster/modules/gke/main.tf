resource "google_container_cluster" "control_plane" {
  name     = var.cluster_name
  location = var.region
  initial_node_count = 1
  remove_default_node_pool = true
 workload_identity_config {
     workload_pool = "${var.project_id}.svc.id.goog"
 }
  private_cluster_config {
    master_ipv4_cidr_block = var.master_ipv4_cidr_block
  }

  network_policy {
    enabled = false
  }

  release_channel {
    channel = "STABLE"
  }
  network = var.vpc
  subnetwork = var.subnet_name

}

resource "google_service_account" "default" {
  account_id   = "service-account-${var.cluster_name}"
  display_name = "Service Account for ${var.cluster_name}"
}

resource "google_container_node_pool" "node_pool" {
  name       = "my-node-pool"
  cluster    = google_container_cluster.control_plane.id
  node_count = 1
  node_config {
    machine_type = "e2-small"
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.default.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    workload_metadata_config {
    mode = "GKE_METADATA"
    }

  }
}