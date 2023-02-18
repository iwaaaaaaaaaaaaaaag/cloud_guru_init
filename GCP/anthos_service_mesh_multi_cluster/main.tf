locals {
  resources = [
    {
      region                 = "${var.region}1"
      subnet_name            = "subnet1"
      subnet_cidr            = "172.16.0.0/16"
      router_name            = "subnet1-${var.region}1-router"
      nat_name               = "subnet1-${var.region}1-nat"
      nat_address_name       = "nat-address1"
      cluster_name           = "cluster1"
      master_ipv4_cidr_block = "192.168.0.0/28"
    },
    {
      region                 = "${var.region}2"
      subnet_name            = "subnet2"
      subnet_cidr            = "172.24.0.0/16"
      router_name            = "subnet1-${var.region}2-router"
      nat_name               = "subnet1-${var.region}2-nat"
      nat_address_name       = "nat-address2"
      cluster_name           = "cluster2"
      master_ipv4_cidr_block = "192.168.8.0/28"
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

module "gke" {
  for_each               = { for i in local.resources : i.region => i }
  source                 = "./modules/gke/"
  cluster_name           = each.value.cluster_name
  region                 = each.value.region
  project_id             = var.project_id
  master_ipv4_cidr_block = each.value.master_ipv4_cidr_block
  vpc                    = google_compute_network.private_network.name
  subnet_name            = each.value.subnet_name
}