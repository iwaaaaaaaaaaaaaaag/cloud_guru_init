#!/bin/bash -e

if [ "$1" != "" ]; then
    printf "project id: %s\n" $1
else 
    echo "set gcp project id to arg"
    exit 1
fi

## tfenv set up
git clone --depth=1 https://github.com/tfutils/tfenv.git ~/.tfenv
export PATH="$HOME/.tfenv/bin:$PATH"
tfenv install 1.0.0
tfenv use 1.0.0

## gcloud config
gcloud auth login
gcloud config set project $1

## enable gcp api
gcloud services enable container.googleapis.com 
gcloud services enable compute.googleapis.com 
gcloud services enable dns.googleapis.com
gcloud services enable anthos.googleapis.com

## set terraform env
export TF_VAR_project_id=$(gcloud config configurations list | awk -F' ' '{print $4}' | tail -n 1)
printf "TF_VAR_project_id: %s" $TF_VAR_project_id