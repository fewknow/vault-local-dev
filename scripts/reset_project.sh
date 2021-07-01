#!/bin/bash

# Reset the project back to a clean slate
# If compose already has a vault running - close that out. 
if docker-compose ps | grep -q vault > /dev/null 2>&1;
then
    cd ${PROJECT_ROOT}
    docker-compose down --remove-orphans
    docker image rm ent-vault
    cd - >/dev/null 2>&1
fi

# Remove TF Configs
printf "\e[0;34m\nRemoving Consul, Orchestrator, Vault and Consul data\e[0m\n"
rm -rf ${PROJECT_ROOT}/_data
rm -rf ${PROJECT_ROOT}/${VAULT_ADDRESS}.crt ${PROJECT_ROOT}/${VAULT_ADDRESS}.key
for directory in $(find ${PROJECT_ROOT}/terraform -type d | sed s@//@/@); do
    find ${directory}/ -type f \( -name ".terraform*" -o -name "terraform.tfstate.d" -o -name "terraform.tfstate" -o -name "terraform.tfstate.backup" -o -name "backend.tf" \) -delete
    # find ${directory}/ -mindepth 1 -type d -name ".terraform" -delete
    printf "\e[0;35m.\e[0m"
done

# Remove app directories from previous projects
printf "\e[0;34m\n\nClearing app data, certs and saved tokens\e[0m\n"
for directory in $(find ${PROJECT_ROOT}/config -type d -mindepth 1 -not -name "cluster_certs" | sed s@//@/@); do
    rm -rf ${directory}
    printf "\e[0;35m.\e[0m"
done

# Clearing Mimir Project Certs
printf "\e[0;34m\n\nClearing local cluster and project created certs\e[0m\n"
for file in $(find ${PROJECT_ROOT}/config -type f -not -name "*.hcl" | sed s@//@/@); do
    rm -rf ${file}
    printf "\e[0;35m.\e[0m"
done
printf "\n"

printf "\e[0;35mReset Complete...\e[0m\n\n"