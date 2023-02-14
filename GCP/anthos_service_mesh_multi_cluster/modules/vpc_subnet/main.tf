#### network ####
resource "google_compute_subnetwork" "private_network_subnet" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = var.vpc_self_link
  private_ip_google_access = true
}
