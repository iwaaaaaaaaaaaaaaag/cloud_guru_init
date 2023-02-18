resource "google_compute_network" "private_network" {
  name                    = "test-network"
  project                 = var.project_id
  auto_create_subnetworks = false
}
