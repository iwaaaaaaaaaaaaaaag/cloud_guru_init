# github actions インストール方法
https://github.com/actions/actions-runner-controller/blob/master/docs/quickstart.md
* kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.2/cert-manager.yaml
* kubectl apply -f \
https://github.com/actions/actions-runner-controller/\
releases/download/v0.22.0/actions-runner-controller.yaml
* kubectl create secret generic controller-manager \
    -n actions-runner-system \
    --from-literal=github_token=<token>
* https://github.com/actions/actions-runner-controller/blob/master/TROUBLESHOOTING.md#internalerror-when-calling-webhook-context-deadline-exceeded
* cat << EOS > runner.yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: runner
  namespace: actions-runner-system
spec:
  replicas: 3
  template:
    spec:
      repository: <user>/<repository>
EOS

sudo apt-get install google-cloud-sdk-gke-gcloud-auth-plugin
gcloud container clusters get-credentials private-gke --zone=us-central1-a
gcloud container clusters get-credentials autopilot-cluster-1 --zone=us-central1-a  

kubectl -n actions-runner-system get pod 

cat << EOS >  action.yaml
name: github action test

on:
  push:
    branches: [ "main" ]

jobs:
  test:
    name: test
    runs-on: self-hosted
    steps:
    - id: test
      run: |
        sleep 100
        echo hello world
EOS

kubectl delete secret controller-manager -n actions-runner-system