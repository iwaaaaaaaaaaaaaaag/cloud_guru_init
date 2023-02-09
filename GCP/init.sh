#!/bin/bash

## tfenv set up
git clone --depth=1 https://github.com/tfutils/tfenv.git ~/.tfenv
export PATH="$HOME/.tfenv/bin:$PATH"
tfenv install 1.0.0
tfenv use 1.0.0

## enable gcp api
gcloud services enable container.googleapis.com 
gcloud services enable compute.googleapis.com 
gcloud services enable dns.googleapis.com

## set terraform env
export TF_VAR_project_id=$(gcloud config configurations list | grep PROJECT: | awk -F' ' '{print $2}')
