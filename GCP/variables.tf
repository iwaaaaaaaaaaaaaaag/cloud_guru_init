variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "project_id" {
  type    = string
  default = "project-id"
}

variable "private_network_name" {
  type    = string
  default = "private-network"
}

variable "public_network_name" {
  type    = string
  default = "public-network"
}

variable "gke_cluster_control_plane_ip_range" {
  type    = string
  default = "172.16.0.0/28"
}

variable "cluster_name" {
  type    = string
  default = "private-gke"
}
