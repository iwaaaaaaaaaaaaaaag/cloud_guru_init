locals {
  resources = [
    {
      region           = "${var.region}1"
      subnet_name      = "subnet1"
      subnet_cidr      = "172.16.0.0/16"
      router_name      = "subnet1-${var.region}1-router"
      nat_name         = "subnet1-${var.region}1-nat"
      nat_address_name = "nat-address1"
    },
    {
      region           = "${var.region}2"
      subnet_name      = "subnet2"
      subnet_cidr      = "172.24.0.0/16"
      router_name      = "subnet1-${var.region}2-router"
      nat_name         = "subnet1-${var.region}2-nat"
      nat_address_name = "nat-address2"
    }
  ]
}

### VPC ### 
resource "google_compute_network" "private_network" {
  name                    = var.private_network_name
  auto_create_subnetworks = false
}

# https://qiita.com/minamijoyo/items/3785cad0283e4eb5a188
module "subnet" {
  for_each      = { for i in local.resources : i.region => i }
  source        = "./modules/vpc_subnet/"
  vpc_self_link = google_compute_network.private_network.self_link
  subnet_name   = each.value.subnet_name
  region        = each.value.region
  subnet_cidr   = each.value.subnet_cidr
}

module "nat" {
  for_each         = { for i in local.resources : i.region => i }
  source           = "./modules/cloud_nat/"
  vpc_self_link    = google_compute_network.private_network.self_link
  router_name      = each.value.router_name
  nat_name         = each.value.nat_name
  nat_address_name = each.value.nat_address_name
  region           = each.value.region
}

resource "google_container_cluster" "primary" {
  name     = "test"
  location = "us-west1"
  initial_node_count = 1
  remove_default_node_pool = true
 workload_identity_config {
     workload_pool = "${var.project_id}.svc.id.goog"
 }
  private_cluster_config {
    master_ipv4_cidr_block = "192.168.0.0/28"
  }

  network_policy {
    enabled = false
  }

  release_channel {
    channel = "STABLE"
  }
  network = "asm-private-network"
  subnetwork = "subnet1"

}
resource "google_service_account" "default" {
  account_id   = "service-account-id"
  display_name = "Service Account"
}

resource "google_container_node_pool" "node_pool" {
  name       = "my-node-pool"
  cluster    = google_container_cluster.primary.id
  node_count = 1
  node_config {
    machine_type = "e2-medium"
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.default.email
    oauth_scopes    = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    workload_metadata_config {
    mode = "GKE_METADATA"
    }

  }
  timeouts {
    create = "30m"
    update = "20m"
  }
}