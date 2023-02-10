#### network ####
resource "google_compute_network" "private_network" {
  name                    = var.private_network_name
  project                 = var.project_id
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "private_network_subnet" {
  name          = "${var.private_network_name}-subnet"
  ip_cidr_range = var.private_network_subnet
  region        = var.region
  network       = google_compute_network.private_network.self_link
  private_ip_google_access = true
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.gke_services_subnet
  }
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.gke_pods_subnet
  }
}

### firewall
resource "google_compute_firewall" "private_network_allow_ingress_my_instance" {
  name          = "${var.private_network_name}-allow-ingress-bastion-instance"
  network       = google_compute_network.private_network.self_link
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

### private gce instance ###
resource "google_compute_address" "bastion_static_ip" {
  name = "bastion-address"
}

resource "google_compute_instance" "my_pri_instance" {
  project      = var.project_id
  zone         = var.zone
  name         = "bastion"
  machine_type = "e2-micro"

  tags = ["bastion"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    subnetwork         = google_compute_subnetwork.private_network_subnet.name
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
      cidr_block   = google_compute_subnetwork.private_network_subnet.ip_cidr_range
      display_name = var.private_network_name
    }
  }
}
