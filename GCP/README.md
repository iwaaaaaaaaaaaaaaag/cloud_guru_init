# GCP
1. [cloud guru sandbox](https://learn.acloud.guru/cloud-playground/cloud-sandboxes)へアクセス
2. GCPを選択しsandbox環境を構築
3. cloud shellを立ち上げて`git clone`
4. `chmod 755 init.sh` を実行
5. `source ./init.sh` を実行

# github actions インストール方法
https://github.com/actions/actions-runner-controller/blob/master/docs/quickstart.md
* kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.8.2/cert-manager.yaml
* kubectl apply --server-side -f \
https://github.com/actions/actions-runner-controller/\
releases/download/v0.22.0/actions-runner-controller.yaml
* kubectl create secret generic controller-manager \
    -n actions-runner-system \
    --from-literal=github_token=REPLACE_YOUR_TOKEN_HERE
* https://github.com/actions/actions-runner-controller/blob/master/TROUBLESHOOTING.md#internalerror-when-calling-webhook-context-deadline-exceeded
* cat << EOS > runner.yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: runner
spec:
  replicas: 3
  template:
    spec:
      repository: iwaaaaaaaaaaaaaaag/github_action_sample
EOS 

sudo apt-get install google-cloud-sdk-gke-gcloud-auth-plugin
gcloud container clusters get-credentials private-gke --zone=us-central1-a
