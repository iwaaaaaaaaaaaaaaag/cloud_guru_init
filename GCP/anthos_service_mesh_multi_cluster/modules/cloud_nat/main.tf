#### cloud nat ####
resource "google_compute_router" "nat_router" {
  name    = var.router_name
  network = var.vpc_self_link
  region = var.region
}

resource "google_compute_address" "nat_address" {
  name = var.nat_address_name
  region = var.region
}

resource "google_compute_router_nat" "nat" {
  name                               = var.nat_name
  nat_ip_allocate_option             = "MANUAL_ONLY"
  router                             = google_compute_router.nat_router.name
  region = var.region
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  min_ports_per_vm                   = 64
  nat_ips                            = [google_compute_address.nat_address.self_link]
}
