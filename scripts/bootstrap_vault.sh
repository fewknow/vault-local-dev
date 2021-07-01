#!/bin/bash
if $(vault --version | grep ent)
then
  VAULT_VERSION=2
else 
  VAULT_VERSION=1
fi

# Build backend files for all directories in the terraform folder
for directory in $(find ${PROJECT_ROOT}/terraform -type d -mindepth 1 -maxdepth 3 | sed s@//@/@); do
    if [[ ${directory} == *tls* ]] | [[ ${directory} == *provisioner* ]] | [[ ${directory} == *orchestrator* ]]; then
      continue
    else
      #rm -f ${directory}/backend.tf
      folder=$(echo ${directory} | awk -F "/" '{print $NF}')
      
      if [ ${VAULT_VERSION} -eq 1 ]
        then
            echo "terraform {
                   backend \"consul\" {
                     path = \"vault/${folder}\"
                   }
                 }" > ${directory}/backend.tf
        fi
    fi
    printf "\e[0;35m.\e[0m"
done

# Function to loop through terraform modules to bootstrap Vault. This repro provides a few default modules as examples and the demos to show you a complete Vault workflow.
printf "\e[0;34m\n\nStarting Bootstrap\n\n\e[0m"

for DIR in $(find ${PROJECT_ROOT}/terraform/vault/bootstrap/ -type d -mindepth 1 -maxdepth 1 | sed s@//@/@ | sort --ignore-case); do
  MODULE="$(basename $(dirname ${DIR}/backend.tf))"

  # Don't offer to bootstrap Enterprise only features with OSS
  if [[ ${VAULT_VERSION} -eq 1 ]] && [[ "${MODULE}" == "kmip_secrets" ]] || [[ "${MODULE}" == "transform_secrets" ]] || [[ "${MODULE}" == "transit_secrets" ]]
  then
     continue
  else   
    printf "\e[0;34mLocation:\e[0m $DIR\n"

    printf "\e[0;34mName:\e[0m $MODULE\n"
    printf "\e[0;34m\nShould TF bootstrap this module? \e[0m"
    read TO_BOOTSTRAP
    echo ""
    
    case $TO_BOOTSTRAP in
    y|Y|yes)
     cd ${DIR}
     #terraform init -backend-config="${PROJECT_ROOT}/config/local-backend-config.hcl" >/dev/null
     terraform init >/dev/null
     terraform apply -var="vault_token=${VR_TOKEN}" -var="vault_addr=${VAULT_ADDRESS}" -var="env=${PROJECT_NAME}"
     if [ ${MODULE} == "cert_auth" ]
     then
        printf "\e[1;32mCerts: [\n${PROJECT_ROOT}/config/${PROJECT_NAME}.crt\n${PROJECT_ROOT}/config/${PROJECT_NAME}.key\n]\n"
     fi
     cd - >/dev/null 2>&1
    ;;
    n|N|no)
    ;;
    *)
      printf "\e[0;34m\nIPATH:\ncorrect selection, skipping... \e[0m\n\n"
    ;;
    esac
  fi
done