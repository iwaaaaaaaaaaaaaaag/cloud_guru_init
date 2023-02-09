#### network ####
resource "google_compute_network" "private_network" {
  name                    = var.private_network_name
  project                 = var.project_id
  auto_create_subnetworks = false
}

resource "google_compute_network" "public_network" {
  name                    = var.public_network_name
  project                 = var.project_id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "private_network_subnet" {
  name          = "${var.private_network_name}-subnet"
  ip_cidr_range = "10.10.20.0/24"
  region        = var.region
  network       = google_compute_network.private_network.self_link
}

resource "google_compute_subnetwork" "public_network_subnet" {
  name          = "${var.public_network_name}-subnet"
  ip_cidr_range = "10.10.10.0/24"
  region        = var.region
  network       = google_compute_network.public_network.self_link
}

#### firewall ####
resource "google_compute_firewall" "public_network_allow_ingress_internal" {
  name          = "public-network-allow-ingress-internal"
  network       = google_compute_network.public_network.self_link
  source_ranges = ["10.0.0.0/8"]

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
}

#### vpc peering ####
resource "google_compute_network_peering" "public_to_private_network" {
  name         = "public-to-private-network"
  network      = google_compute_network.public_network.self_link
  peer_network = google_compute_network.private_network.self_link
}

resource "google_compute_network_peering" "private_to_public_network" {
  name         = "public-to-private-network"
  network      = google_compute_network.private_network.self_link
  peer_network = google_compute_network.public_network.self_link
}

### google private access ###
# https://blog.g-gen.co.jp/entry/private-google-access-explained
resource "google_dns_managed_zone" "google_apis" {
  project    = var.project_id
  name       = "google-apis"
  dns_name   = "googleapis.com."
  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.private_network.id
    }
  }
}

resource "google_dns_record_set" "google_apis_cname" {
  project      = var.project_id
  managed_zone = google_dns_managed_zone.google_apis.name
  name         = "*.${google_dns_managed_zone.google_apis.dns_name}"
  type         = "CNAME"
  ttl          = 300

  rrdatas = ["restricted.googleapis.com."]
}

resource "google_dns_record_set" "google_apis_a" {
  project      = var.project_id
  managed_zone = google_dns_managed_zone.google_apis.name
  name         = "restricted.googleapis.com."
  type         = "A"
  ttl          = 300

  rrdatas = ["199.36.153.4", "199.36.153.5", "199.36.153.6", "199.36.153.7"]
}

### cloud nat ###
resource "google_compute_router" "nat_router" {
  name    = "${var.private_network_name}-router"
  network = google_compute_network.private_network.self_link
}

#resource "google_compute_address" "nat_address" {
#  name    = "nat-address"
#}

resource "google_compute_router_nat" "nat" {
  name                                = "${var.private_network_name}-nat"
  nat_ip_allocate_option              = "AUTO_ONLY"
  router                              = "${var.private_network_name}-router"
  source_subnetwork_ip_ranges_to_nat  = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  min_ports_per_vm = 64
}

### public gce instance ###
resource "google_compute_instance" "my_pub_instance" {
  project       = var.project_id
  zone          = "${var.region}-a"
  name          = "bastion"
  machine_type = "e2-micro"

  tags = ["bastion"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    subnetwork         = "${var.public_network_name}-subnet"
    subnetwork_project = var.project_id
    access_config {
      nat_ip = google_compute_address.bastion_static_ip.address
    }
  }

  service_account {
    scopes = ["cloud-platform"]
  }
}   

resource "google_compute_address" "bastion_static_ip" { 
  name = "bastion-address"
}