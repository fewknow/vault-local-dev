ROOT=`pwd`
TOKEN=$1
ENV=$2

terraform_path=`pwd`
terraform_path="$terraform_path/terraform"
#cd local-vault-dev


for path in terraform/vault/bootstrap/*; do
  printf "\e[1;34m\nPATH : $path\e[0m"
  if [ -d "${path}" ]; then
    IFS='/' read -ra my_array <<< "$path"
    len=${#my_array[@]}
    # echo "length : $len"
    PROJECT="${my_array[$len-1]}"
    printf "\nPROJECT : $PROJECT"
    #printf "\e[1;34m\nterraform path: $terraform_path \e[0m\n"
    printf "\e[1;34m\nShould TF bootstrap this module? \e[0m"
    read THIS_MODULE

    case $THIS_MODULE in
    y|Y|yes)
     echo "terraform init for ${path}"
     echo "cd into ${path}"
     cd ${path}

     echo "attempting: terraform init -backend-config=${terraform_path}/local-backend.config"
     terraform init -backend-config="${terraform_path}/local-backend.config"

     echo "attempting terraform apply -var=vault_token=${TOKEN} -var=vault_addr=https://localhost:8200"
     terraform apply -var="vault_token=${TOKEN}" -var="vault_addr=https://localhost:8200" -var="env=$ENV"
    ;;
    n|N|no)
    ;;      
    *)
      printf "\e[1;34m\nIncorrect selection, skipping... \e[0m\n\n"
    ;;
    esac

    # echo "back to $ROOT"
    cd $ROOT
  fi
done
