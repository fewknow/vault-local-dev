ROOT=`pwd`
TOKEN=$1
export VAULT_ADDR="https://localhost:8200"

cd ..
terraform_path=`pwd`
terraform_path="$terraform_path/terraform"
cd local-vault-dev

cd ../terraform/apps
terraform init -backend-config="${terraform_path}/local-backend.config" -backend-config="path=vault/apps"
#terraform init -backend-config=../../../local-backend.config -backend-config="path=vault/apps"
terraform apply -var="token=$TOKEN"
