#!/bin/bash

## Script designed to automate the setup the Local Vault Development Project as part of the Mimir initiative. 

# Function to unseal OSS vaults
function unseal_vault(){
    printf "\e[0;34m\n\nAttempting unseal process now...\n\n\e[0m"
    for i in $(cat ${KEYS_FILE} | awk "/Unseal Key/ {print \$4}"); do
        UNSEAL_KEY=${i}
        vault operator unseal -address=${VAULT_ADDR} "$UNSEAL_KEY"
        echo ""
    done
}

############################
#### Script Starts Here ####
############################

# Set project config
export VAULT_SKIP_VERIFY=true
VAULT_ADDRESS="https://127.0.0.1:8200"
export VAULT_ADDR=${VAULT_ADDRESS}

# Absolute path to the project root based on this scripts location. 
PROJECT_ROOT=$(dirname $(cd `dirname $0` && pwd))
# File to store the restore/recovery keys and the root token
KEYS_FILE="${PROJECT_ROOT}/_data/keys.txt"
# AWS bucket name holding the Enterprise License file
BUCKET_NAME="ian-bucket-dev"
# Name of the license file in the AWS bucket above
LICENSE_FILE="license.txt"

# Dependency check, both OSS and ENT Vault Versions. 
if ! which vault >/dev/null 2>&1
then
    printf "\e[0;34m\nVault not installed, please install to continue...\e[0m\n\n"
    exit 0
elif ! which terraform >/dev/null 2>&1
then
    printf "\e[0;34m\nTerraform not installed, please install to continue...\e[0m\n\n"
    exit 0
elif ! which docker >/dev/null 2>&1
then
    printf "\e[0;34m\nDocker not installed, please install to continue...\e[0m\n\n"
    exit 0
fi

# Get user input
printf "\e[0;32m\n## Vault/Consul ##\e[0m\n\n"
printf "\e[0;34m\nWhere would you like to start? \n\n\e[0m"
printf "   1. Quick Start\n"
printf "   2. Bootstrap\n"
printf "   3. Demos\n"
printf "   4. Reset local project\n"
printf "   5. Exit\n"
printf "\n: "
read MAIN_MENU

case ${MAIN_MENU} in
1)
    #######################
    ### Full Script Run ###
    #######################

    # Clean old files and compose projects
    if ls ${PROJECT_ROOT}/_data >/dev/null 2>&1;
    then
        PROJECT_NAME=`ls ${PROJECT_ROOT}/config/cluster_certs | awk -F'.' '/srl/ {print $1}'`

        printf "\e[0;34m\nOld Vault/Consul data found for project:\e[0m ${PROJECT_NAME}\e[0;34m, reset before continuing? \e[0m"
        read RESET_PROJECT
        
        case $RESET_PROJECT in 
        y|yes|Y)
            # Clear old project files
            source ${PROJECT_ROOT}/scripts/reset_project.sh

            # Get Project Name
            printf "\e[0;34mName your new project: \e[0m"
            read PROJECT_NAME
            PROJECT_NAME=$(echo $PROJECT_NAME | awk '{print tolower($0)}')
            # Set environment so TF can pickup the var.
            export TF_VAR_env=${PROJECT_NAME}
        ;;
        n|no|N)
            export TF_VAR_env=${PROJECT_NAME}
        ;;
        esac
    else 
        # Get Project Name
        printf "\e[0;34mName your new project: \e[0m"
        read PROJECT_NAME

        # Update project name to be all lower case. 
        PROJECT_NAME=$(echo $PROJECT_NAME | awk '{print tolower($0)}')

        # Set environment so TF can pickup the var.
        export TF_VAR_env=${PROJECT_NAME}
    fi

    printf "\e[0;34m\nWhich type of Vault?\n\e[0m"
    printf " 1. OSS\n"
    printf " 2. Enterprise\n"
    printf "\n: "
    read VAULT_VERSION

    # Verify certs have been created for the local vault service
    source ${PROJECT_ROOT}/scripts/cluster_certs.sh

    case ${VAULT_VERSION} in
    1)
        #################
        ### OSS Vault ###
        #################

        # Check if docker is already running with a vault image
        if ! docker ps 2>/dev/null | grep -q "vault";
        then
            # Start the new project in dettached docker
            printf "\e[0;34m\nStarting ${PROJECT_NAME} docker-compose project detached\e[0m\n\n"
            cd ${PROJECT_ROOT}
            docker-compose -f docker-compose.yml up -d

            # Advise we are waiting for the project to complete the startup process
            printf "\e[0;34m\nWaiting for Vault Service to complete startup\e[0m\n"
            until curl ${VAULT_ADDRESS}/v1/status 2>/dev/null | grep -q "Vault"
            do
                printf "\e[0;35m.\e[0m"
                sleep 3
                if ! docker ps | grep -q "vault";
                then 
                    printf "\e[0;34m\nVault failed to start, getting container logs...\e[0m\n"
                    docker-compose logs vault 
                fi
            done

            # init Vault
            printf "\e[0;34m\n\nStarting Vault Init\n\e[0m"
            vault operator init -key-shares=3 -key-threshold=2 -address=${VAULT_ADDRESS} > ${KEYS_FILE}

            # Unseal Vault
            printf "\e[0;34m\nUnseal keys and token stored in\e[0m ${KEYS_FILE}\n"
            printf "\e[0;35m\nPress any key to continue\e[0m\n"
            read -n 1 -s -r
            unseal_vault
        else
            if [[ $(vault status | awk "/Sealed/ {print \$2}") == 'true' ]];then
                sleep 2
                # Unseal Vault
                unseal_vault
            fi
        fi

        # Get the vault root token and your local ip
        VR_TOKEN=`cat ${PROJECT_ROOT}/_data/keys.txt | grep Initial | cut -d':' -f2 | tr -d '[:space:]'`
        export VAULT_TOKEN="${VR_TOKEN}"
    ;;
    2)
        #################
        ### Ent Vault ###
        #################

        # Check if docker is already running with a vault image
        if ! docker ps 2>/dev/null | grep -q "vault"; then
        
            if ! which aws >/dev/null 2>&1
            then
                printf "\e[0;34m\nAWS CLI is not installed, this is needed for access to KMS and S3 for the license - please install to continue...\e[0m\n\n"
                exit 0
            fi

            if ! aws s3api list-buckets > /dev/null 2>&1;
            then
                printf "\e[0;34m\nAWS Access not configured, please run `aws configure` to continue.\e[0m\n\n"
                exit 0
            fi


            # Check if Vault Enterprise image exists on host and is specified in the ent-docker-compose.yml file 
            if ! docker image ls | grep -q 'ent-vault' && cat ${PROJECT_ROOT}/ent-docker-compose.yml | grep -q '        image: "ent-vault:latest"'; then
                printf "\e[0;34m\nDocker Vault Enterprise image not found on system - creating now:\n\n\e[0m"
                cd ${PROJECT_ROOT}
                docker build -t ent-vault .

                # Start the new project in detached docker
                printf "\e[0;34m\nStarting ${PROJECT_NAME} docker-compose project detached\e[0m\n\n"
                cd ${PROJECT_ROOT}
                docker compose -f ent-docker-compose.yml up -d 
            else
                # Start the new project in detached docker
                printf "\e[0;34m\nStarting ${PROJECT_NAME} docker-compose project detached\e[0m\n\n"
                cd ${PROJECT_ROOT}
                docker compose -f ent-docker-compose.yml up -d
            fi

            # Advise we are waiting for the project to complete the startup process
            printf "\e[0;34m\nWaiting for Vault to complete initial startup\e[0m\n"
            until curl ${VAULT_ADDRESS}/v1/status 2>/dev/null | grep -q "Vault"
            do
                # >/dev/null 2>&1
                printf "\e[0;35m.\e[0m"
                sleep 3
                if ! docker ps | grep -q "vault";
                then 
                    printf "\e[0;34m\nVault failed to start, getting container logs...\e[0m\n"
                    docker compose logs vault 
                fi
            done

            mkdir -p ${PROJECT_ROOT}/_data 
            
            # init Vault
            printf "\e[0;34m\n\nStarting Vault Operator Init\n\e[0m"
            vault operator init -address=${VAULT_ADDRESS} > ${KEYS_FILE}

            # Unseal Vault
            printf "\e[0;34m\nUnseal keys and token stored in\e[0m ${KEYS_FILE}\n"
            printf "\e[0;35m\nPress any key to continue\e[0m\n"
            read -n 1 -s -r
        else
            printf "\e[0;34m\nDocker already started with vault service, continuing\n\e[0m"
        fi

        # Get the vault root token and your local ip
        VR_TOKEN=`cat ${PROJECT_ROOT}/_data/keys.txt | grep Initial | cut -d':' -f2 | tr -d '[:space:]'`
        export VAULT_TOKEN="${VR_TOKEN}"

        printf "\n\e[0;34mDownloading License from S3\n\e[0m"
        until $( aws s3api get-object --bucket ${BUCKET_NAME} --key ${LICENSE_FILE} license.txt >/dev/null )
        do
            printf "\e[0;35m.\e[0m"
            sleep 1
        done

        printf "\e[0;34mInstalling license\n\e[0m"
        sleep 2
        until $( curl -s --request PUT --header "X-Vault-Token: ${VR_TOKEN}" -d @license.txt ${VAULT_ADDRESS}/v1/sys/license >/dev/null )
        do
            printf "\e[0;35m.\e[0m"
            sleep 1
        done

        rm -f license.txt

        # Make sure JQ is installed. 
        if [ ! jq > /dev/null ];
        then
            brew install jq 
        fi

        printf "\e[0;34mCheck license is now non-temporary\n\e[0m"
        curl -s --header "X-Vault-Token: ${VR_TOKEN}" ${VAULT_ADDRESS}/v1/sys/license | jq '.data'
    ;;
    esac

    # Bootstrap the vault configuration
    printf "\e[0;34mDo you want to bootstap Vault?\e[0m i.e Create example auth methods, secret engines, and policies? "
    read BOOTSTRAP

    case $BOOTSTRAP in
    y|Y|yes)
        # Setup terraform backend
        printf "\e[0;34m\n\nCreating Terraform backend.tf for all modules - Pointing to our consul cluster\e[0m\n"
        source ${PROJECT_ROOT}/scripts/bootstrap_vault.sh
    ;;
    *)
        printf "\e[0;34m\nSkipping Bootstrap\n\n\e[0m"
    ;;
    esac

    printf "\nBasic Vault setup complete!\n\nYou can now login to Vault with any of the auth methods bootstrapped.\n\n"

    # Run demo function
    source ${PROJECT_ROOT}/scripts/demos.sh
;;
2)
    ##########################################
    ### Bootstrap An Already Running Vault ###
    ##########################################

    PROJECT_NAME=$(ls ${PROJECT_ROOT}/config/cluster_certs/ | grep -v localhost | awk -F'.' '/crt/ {print $1}')
    export TF_VAR_env=${PROJECT_NAME}

    printf "\e[0;32m\nWhere is your Vault?\e[0m\n"
    printf " 1. Local Vault\n"
    printf " 2. Remote Vault\n"
    read VAULT_LOCATION

    # Get project name 
    case ${VAULT_LOCATION} in
    1)
        VR_TOKEN=`cat ${PROJECT_ROOT}/_data/keys.txt | grep Initial | cut -d':' -f2 | tr -d '[:space:]'`
    ;;
    2)
        printf "\e[0;34m\nPlease enter the Vault Token: "
        read REMOTE_KEY_BUCKET
        printf "\e[0;34m\nPlease enter the Vault address: "
        read REMOTE_VAULT_ADDR
        VAULT_ADDRESS="http://${REMOTE_VAULT_ADDR}:8200"
        #aws s3api get-object --bucket ${REMOTE_KEY_BUCKET} --key vault_credentials.txt ${PROJECT_ROOT}/license.txt > /dev/null
        VR_TOKEN=${REMOTE_KEY_BUCKET}
        
    ;;
    esac

    # printf "\e[0;34m\nChange/Set the Terraform backend before bootstrapping?\e[0m " 
    # read RESET_BACKEND

    # case $RESET_BACKEND in 
    # y|Y|yes)
    #   # Setup terraform backend
    #   set_backend
    # ;;
    # *)
    # ;;
    # esac

    # Starting bootstrap
    source ${PROJECT_ROOT}/scripts/bootstrap_vault.sh
    # Starting Demos
    source ${PROJECT_ROOT}/scripts/demos.sh
;;
3)
    #################
    ### Run Demos ###
    #################

    PROJECT_NAME=$(ls ${PROJECT_ROOT}/config/cluster_certs/ | grep -v localhost | awk -F'.' '/crt/ {print $1}')
    export TF_VAR_env=${PROJECT_NAME}

    if VR_TOKEN=`cat ${PROJECT_ROOT}/_data/keys.txt | grep Initial | cut -d':' -f2 | tr -d '[:space:]'`;
    then
        # Start Demos
        source ${PROJECT_ROOT}/scripts/demos.sh
    else
        printf "\e[0;34m\nRoot token not found in:\e[0m ${PROJECT_ROOT}/_data\n"
        printf "\e[0;34m\nPlease rerun this script and choose 'Start From The Begining'\n"
    fi
;;
4)
    #####################
    ## Reset Local Env ##
    #####################

    source ${PROJECT_ROOT}/scripts/reset_project.sh
;;
5)
    #######################
    ### Exit The Script ###
    #######################
    exit 0
;;
*)
    ######################
    ### Error Catching ###
    ######################

    printf "\e[0;34m\nInvalid Selection, please try again.\n\n"
    ${PROJECT_ROOT}/scripts/$(basename $0) && exit
;;
esac
