#!/bin/bash

## tfenv set up
git clone --depth=1 https://github.com/tfutils/tfenv.git ~/.tfenv
export PATH="$HOME/.tfenv/bin:$PATH"
tfenv install 1.0.0
tfenv use 1.0.0

## enable gcp api
gcloud services enable container.googleapis.com

## set project
GCP_PROJECT=$(gcloud config configurations list | grep PROJECT: | awk -F' ' '{print $2}')
sed s/GCP_PROJECT/$GCP_PROJECT/g provider.tf_tmp > provider.tf
rm provider.tf_tmp

## do terraform 
terraform init
terraform plan
terraform apply -auto-approve
