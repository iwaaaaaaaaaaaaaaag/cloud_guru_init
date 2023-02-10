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
  private_ip_google_access = true
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.10.21.0/24"
  }
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.20.0.0/16"
  }
}

resource "google_compute_subnetwork" "public_network_subnet" {
  name          = "${var.public_network_name}-subnet"
  ip_cidr_range = "10.10.10.0/24"
  region        = var.region
  network       = google_compute_network.public_network.self_link
}

#### firewall ####
resource "google_compute_firewall" "public_network_allow_ingress_internal" {
  name          = "${var.public_network_name}-allow-ingress-internal"
  network       = google_compute_network.private_network.self_link
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

resource "google_compute_firewall" "public_network_allow_ingress_my_instance" {
  name          = "${var.public_network_name}-allow-ingress-bastion-instance"
  network       = google_compute_network.public_network.self_link
  source_ranges = ["0.0.0.0/0"]


  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["bastion"]
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

resource "google_compute_address" "nat_address" {
  name = "nat-address"
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.private_network_name}-nat"
  nat_ip_allocate_option             = "MANUAL_ONLY"
  router                             = google_compute_router.nat_router.name
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  min_ports_per_vm                   = 64
  nat_ips                            = [google_compute_address.nat_address.self_link]
}

### public gce instance ###
resource "google_compute_instance" "my_pub_instance" {
  project      = var.project_id
  zone         = "${var.zone}"
  name         = "bastion"
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

  metadata_startup_script = "apt-get install kubectl"

}

resource "google_compute_address" "bastion_static_ip" {
  name = "bastion-address"
}

### GKE ###
# private google access用のegress
resource "google_compute_firewall" "private_gke_network_allow_egress_google_apis" {
  name               = "private-gke-network-allow-egress-google-apis"
  network            = google_compute_network.private_network.self_link
  direction          = "EGRESS"
  destination_ranges = ["199.36.153.4/30"]

  allow {
    protocol = "all"
  }
}

# コントロールプレーン用のegress
resource "google_compute_firewall" "private_gke_network_allow_egress_masternode" {
  name               = "private-gke-network-allow-egress-masternode"
  network            = google_compute_network.private_network.self_link
  direction          = "EGRESS"
  destination_ranges = [var.gke_cluster_control_plane_ip_range]

  allow {
    protocol = "tcp"
    ports    = ["443", "10250"]
  }
}

# gke
resource "google_container_cluster" "primary" {
  name               = var.cluster_name
  location           = var.zone
  initial_node_count = 1
  network            = google_compute_network.private_network.name
  subnetwork         = google_compute_subnetwork.private_network_subnet.name

  private_cluster_config {
    enable_private_nodes    = true # 各ノードのパブリックIPを無効化
    enable_private_endpoint = true # マスターノードのパブリックエンドポイントを無効化
    master_ipv4_cidr_block  = var.gke_cluster_control_plane_ip_range
  }

  ip_allocation_policy {
    cluster_secondary_range_name   = "pods"
    services_secondary_range_name  = "services"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = google_compute_subnetwork.public_network_subnet.ip_cidr_range
      display_name = var.public_network_name
    }
  }
}
