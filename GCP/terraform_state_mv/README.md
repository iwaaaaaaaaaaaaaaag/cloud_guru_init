## terraform state mv
### 検証方法
1. 
cat << EOF >> vpc1.tf
resource "google_compute_network" "private_network" {
  name                    = "test-network"
  project                 = var.project_id
  auto_create_subnetworks = false
}
EOF
2. terraform plan
3. terraform apply
4. 
cat << EOF >> vpc2.tf
module "module_sample" {
  source           = "./module/"
  project_id = var.project_id
}
EOF

5. 
cat << EOF >> module/vpc2.tf
resource "google_compute_network" "private_network" {
  name                    = "test-network"
  project                 = var.project_id
  auto_create_subnetworks = false
}
EOF
6. rm vpc1.tf 
7. terraform init
8. terraform plan
差分がでる
9. terraform state mv -state=terraform.tfstate google_compute_network.private_network module.module_sample.google_compute_network.private_network
差分が出ない
10. terraform plan
11. terraform apply

## リモートに影響を与えない方法
* tfmigrate
* moved block
### moved block
### 検証方法
1. 
cat << EOF >> vpc1.tf
resource "google_compute_network" "private_network" {
  name                    = "test-network"
  project                 = var.project_id
  auto_create_subnetworks = false
}
EOF
2. terraform plan
3. terraform apply -auto-approve
4. 
cat << EOF >> vpc2.tf
module "module_sample" {
  source           = "./module/"
  project_id = var.project_id
}

moved {
  from = google_compute_network.private_network
  to   = module_sample.google_compute_network.private_network
}
EOF

5. 
cat << EOF >> module/vpc2.tf
resource "google_compute_network" "private_network" {
  name                    = "test-network"
  project                 = var.project_id
  auto_create_subnetworks = false
}
EOF
6. rm vpc1.tf 
7. tfenv install 1.1.0
8. tfenv use 1.1.0
7. terraform init
8. terraform plan
差分がでる
9. terraform state mv -state=terraform.tfstate google_compute_network.private_network module.module_sample.google_compute_network.private_network
差分が出ない
10. terraform plan
11. terraform apply

### 所感
terraform state mvコマンドを実行するとtfstateを即座に変更する

## 参考
* https://tech.fusic.co.jp/posts/2021-10-26-tf-state-mv-1/
* https://qiita.com/minamijoyo/items/b4d70787556c83f289e7