ROOT=`pwd`
TOKEN=$1
export VAULT_ADDR="https://localhost:8200"

terraform_path=${PWD}/terraform

cd ${terraform_path}/apps
terraform init -backend-config="${terraform_path}/local-backend.config" -backend-config="path=vault/apps"
terraform apply -var="token=$TOKEN"
