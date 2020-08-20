ROOT=`pwd`
TOKEN=$1

terraform_path=`pwd`
terraform_path="$terraform_path/terraform"
cd local-vault-dev


for path in terraform/vault/bootstrap/*; do
  echo "PATH : $path"
  if [ -d "${path}" ]; then
     IFS='/' read -ra my_array <<< "$path"
     len=${#my_array[@]}
     echo "length : $len"
     PROJECT="${my_array[$len-1]}"
     echo "PROJECT : $PROJECT"
     echo "terraform path: $terraform_path"
     echo "terraform init for ${path}"
     echo "cd into ${path}"
     cd ${path}

     echo "attempting: terraform init -backend-config=${terraform_path}/local-backend.config"
     terraform init -backend-config="${terraform_path}/local-backend.config"

     echo "attempting terraform apply -var="token=$TOKEN""
     terraform apply -var="token=$TOKEN"

     echo "back to $ROOT"
     cd $ROOT
  fi
done
