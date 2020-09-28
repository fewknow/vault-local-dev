#!/bin/bash

# Colors:
# red=$'\e[1;31m'
# grn=$'\e[0;32m'
# yel=$'\e[1;33m'
# blu=$'\e[0;34m'
# mag=$'\e[1;35m'
# cyn=$'\e[1;36m'
# end=$'\e[0m'

## Script designed to automate the setup of this entire project. 
function app_roles(){

    cd ${PROJECT_ROOT}/terraform/apps
    terraform init
    terraform apply -var="token=${VR_TOKEN}"
    cd - >/dev/null 2>&1

}

function bootstrap_vault(){
    for DIR in $(find ${PROJECT_ROOT}/terraform/vault/bootstrap/ -type d -mindepth 1 -maxdepth 1 | sed s@//@/@); do
        printf "\e[0;34m\nPATH:\e[0m $DIR\n"
        MODULE="$(basename $(dirname ${DIR}/backend.tf))"

        printf "\e[0;34mModule:\e[0m $MODULE\n"
        printf "\e[0;34m\nShould TF bootstrap this module? \e[0m"
        read TO_BOOTSTRAP   

        case $TO_BOOTSTRAP in
        y|Y|yes)
         echo "terraform init for ${DIR}"
         echo "cd into ${DIR}"
         cd ${DIR} 
         echo "attempting: terraform init -backend-config=${PROJECT_ROOT}/terraform/local-backend.config"
         terraform init -backend-config="${PROJECT_ROOT}/terraform/local-backend.config"    
         echo "attempting terraform apply -var=vault_token=${VR_TOKEN} -var=vault_addr=${VAULT_ADDR}"
         terraform apply -var="vault_token=${VR_TOKEN}" -var="vault_addr=${VAULT_ADDR}" -var="env=${PROJECT_NAME}"
         if [ ${MODULE} == "pki_secrets" ]
         then
            # Configuring Root and Intermediate CA
            create_root_cert
        fi
         cd - >/dev/null 2>&1
        ;;
        n|N|no)
        ;;      
        *)
          printf "\e[0;34m\nIncorrect selection, skipping... \e[0m\n\n"
        ;;
        esac
    done
}

function build_local_certs(){
    # Get local ip address and add it to our certificate request 
    IFIP=`ifconfig | awk '/broadcast/{print $2}'`
    printf "authorityKeyIdentifier=keyid,issuer\nbasicConstraints=CA:FALSE\nkeyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment\nsubjectAltName = @alt_names\n[alt_names]\nDNS.1 = localhost\nIP.1 = ${IFIP}\nIP.2 = 127.0.0.1" > domains.ext

    # Generate the project certificates
    cd ${PROJECT_ROOT}/config
    rm -f *.pem *.crt *.key *.csr *.srl
    # Genrating CA
    printf "\e[0;34m\nGenerating CA Certs\e[0m\n\n"
    openssl req -x509 -nodes -new -sha256 -days 1024 -newkey rsa:4096 -keyout ${PROJECT_NAME}.key -out ${PROJECT_NAME}.pem -subj "/C=US/ST=YourState/L=YourCity/O=${PROJECT_NAME}/CN=localhost.local"
    openssl x509 -outform pem -in ${PROJECT_NAME}.pem -out ${PROJECT_NAME}.crt
    # Generating Vault/Consul certificates
    printf "\e[0;34mGenerating Vault/Consul Certs\e[0m\n\n"
    openssl req -new -nodes -newkey rsa:4096 -keyout localhost.key -out localhost.csr -subj "/C=US/ST=YourState/L=YourCity/O=${PROJECT_NAME}/CN=localhost.local"
    openssl x509 -req -sha256 -days 1024 -in localhost.csr -CA ${PROJECT_NAME}.pem -CAkey ${PROJECT_NAME}.key -CAcreateserial -extfile ${PROJECT_ROOT}/config/domains.ext -out localhost.crt

    # Add new localhost.crt to your keychain as 'Always Trusted'
    printf "\e[0;34m\nAdding new cert to keychain and setting as 'Always Trust - If prompted, please enter your 'sudo' password below.\e[0m\n\n'"
    sudo /usr/bin/security -v add-trusted-cert -r trustAsRoot -e hostnameMismatch -d -k /Library/Keychains/System.keychain localhost.crt >/dev/null 2>&1
    cd - >/dev/null 2>&1
}

function cert_check() {
    # Certiicate check
    if ls ${PROJECT_ROOT}/config/ | grep -q 'localhost.crt' && ls ${PROJECT_ROOT}/config | grep -q 'localhost.key';then

        printf "\e[0;34m\nCluster Certs found, using the following files: \e[0m\n\n"
        ls ${PROJECT_ROOT}/config | grep "localhost.crt\|localhost.key"

        # Verify localhost.crt is added to our keychain
        if security export -k /Library/Keychains/System.keychain -t certs | grep -q `cat ${PROJECT_ROOT}/config/localhost.crt | sed '/^-.*-$/d' | head -n 1`; then
            printf "\e[0;34m\nCert found in your local Keychain\e[0m\n\n"
        else
            printf "\e[0;34m\nCert not found in keychain, adding now as 'Always Trusted'\e[0m"
            sudo /usr/bin/security -v add-trusted-cert -r trustAsRoot -e hostnameMismatch -d -k /Library/Keychains/System.keychain localhost.crt >/dev/null 2>&1
        fi
    else 
        printf "Cert files not found in '${PROJECT_ROOT}/config', please add the following for use within the vault/consul cluster: localhost.key, localhost.crt\n"
        read -p "Instead, would you like to generate new certs now? " CERTS_BOOL

        case $CERTS_BOOL in 
        y|Y|yes)
            build_local_certs
        ;;
        n|N|No)
            printf "\n Exiting, please add certs and restart this script or use the generate certs option...\n\n"
            exit 0
        ;;
        esac 
    fi
}

function create_root_cert(){
    printf "\e[0;34mConfiguring Root and Intermediate CA, please wait...\e[0m\n"
    sleep 5
    vault login ${VR_TOKEN} 2>/dev/null
    vault write -field=certificate pki_engine/root/generate/internal \
        common_name="${PROJECT_NAME}.com" \
        ttl=87600h > ${PROJECT_ROOT}/config/root_ca_cert.crt

    vault write pki_engine/config/urls \
        issuing_certificates="http://127.0.0.1:8200/v1/pki_engine/ca" \
        crl_distribution_points="http://127.0.0.1:8200/v1/pki_engine/crl"

    vault write -format=json pki_int/intermediate/generate/internal \
        common_name="${PROJECT_NAME}.com Intermediate Authority" \
        | jq -r '.data.csr' > ${PROJECT_ROOT}/config/pki_intermediate.csr

    vault write -format=json pki_engine/root/sign-intermediate csr=@${PROJECT_ROOT}/config/pki_intermediate.csr \
        format=pem_bundle ttl="43800h" \
        | jq -r '.data.certificate' > ${PROJECT_ROOT}/config/pki_intermediate.cert.pem

    vault write pki_int/intermediate/set-signed certificate=@${PROJECT_ROOT}/config/pki_intermediate.cert.pem

    PKI_ENGINE=true
}

function orchestrator(){
    if ls /Library/Python/2.7/site-packages/ | grep -q "requests"
    then
        continue
    else
        # Install Python module 'requests'
        printf "\e[0;34m\nRequests module needed, please enter your sudo password below to complete the pip3 installation\n\e[0m"
        sudo easy_install requests==2.22.0
    fi

    # Make App dir and generate a cert for our app
    mkdir ${PROJECT_ROOT}/config/${APP_NAME} && cd $_
    printf "\e[0;34m\nCreating Application Certificats in:\e[0m ${PROJECT_ROOT}/config/${APP_NAME}\n\n"
    python ${PROJECT_ROOT}/terraform/orchestrator/vault_cert_gen.py -T ${VR_TOKEN} -U "https://localhost:8200" -C "${APP_NAME}.com" -TTL "1h"
    cd - >/dev/null 2>&1

    cd ${PROJECT_ROOT}/terraform/orchestrator/tls
    printf "\e[0;34m\nCerts Created, Creating Cert Auth Role:\e[0m ${APP_NAME}\n\n"
    sleep 2
    terraform init
    terraform apply -var="app=${APP_NAME}" -var="vault_token=${VR_TOKEN}"
    cd - >/dev/null

    cd ${PROJECT_ROOT}/terraform/orchestrator/provisioner
    printf "\e[0;34m\nCreating Provisioner Token to be used when deplaying:\e[0m ${APP_NAME}\n\n"
    sleep 2
    terraform init
    terraform apply -var="vault_token=${VR_TOKEN}"
    cd - >/dev/null 2>&1
}

function reset_local(){
    printf "\e[0;34m\nShould this script stop your previous Mimir docker-compose project? \e[0m"
    read STOP_COMPOSE
    
    # If true, stop any docker-compose projects built with this project.
    case $STOP_COMPOSE in
    y|Y|yes)
        cd ${PROJECT_ROOT}
        docker-compose down
        cd - >/dev/null 2>&1
    ;;
    n|N|no)
    ;;
    *)
        printf "\n Invalid section, please use the format 'Y|N'\n\n"
        reset_local
    esac

    printf "\e[0;34m\nShould previously used files be removed before starting this build? i.e consul data, apps, orchestrator: \e[0m "
    read RESET_BOOL

    # If true, delete all previous terraform configs, states etc.
    case $RESET_BOOL in 
    y|Y|yes)
        printf "\e[0;34m\nClearing apps, Consul, Orchestrator, Vault and Consul data\e[0m\n"
        rm -rf ${PROJECT_ROOT}/_data
        rm -rf ${PROJECT_ROOT}/localhost.crt ${PROJECT_ROOT}/localhost.key
        printf "\e[0;34m\nRecursively deleting the following files from\e[0m ${PROJECT_ROOT}/terraform:\n\n.terraform | terraform.tfstate.d | terraform.tfstate | terraform.tfstate.backup | backend.tf\e[0;34m\n\n"
        for directory in $(find ${PROJECT_ROOT}/terraform -type d | sed s@//@/@); do
            find ${directory}/ -type f \( -name ".terraform" -o -name "terraform.tfstate.d" -o -name "terraform.tfstate" -o -name "terraform.tfstate.backup" -o -name "backend.tf" \) -delete
        done
    ;;
    n|N|No)
    ;;
    esac
 
   printf "\n\e[0;31mWarning: this will remove all cert files in ${PWD}/config\e[0m \n"
   printf '\e[0;34m%-6s\e[m' "Should we generate new certs for this project? "
   read CERTS_BOOL
   
   # If true, remove all certs found in the project config dir - otherwise, call the method to verify needed certs exist. 
    case $CERTS_BOOL in 
    y|Y|yes)
        build_local_certs
    ;;
    n|N|no)
        cert_check
    ;;
    esac
}

function set_backend(){
    sleep 2
    for directory in $(find ${PROJECT_ROOT}/terraform -type d -mindepth 1 -maxdepth 3 | sed s@//@/@); do
        if [[ ${directory} == *tls* ]] | [[ ${directory} == *provisioner* ]] | [[ ${directory} == *orchestrator* ]]; then
          continue
        else
          rm -f ${directory}/backend.tf
          folder=$(echo ${directory} | awk -F "/" '{print $NF}')
          printf "\e[0;34mEntity:\e[0m ${folder}\n"
          printf "\e[0;34mCreating\e[0m ${directory}/backend.tf\n\n"
          echo "terraform {
                 backend \"consul\" {
                   path = \"vault/${folder}\"
                 }
               }" > ${directory}/backend.tf
        fi
    done
}

function unseal_vault(){
    printf "\e[0;34m\nAttempting unseal process now...\n\n\e[0m"
    for i in $(cat ${KEYS_FILE} | awk "/Unseal Key/ {print \$4}"); do
        UNSEAL_KEY=${i}
        vault operator unseal -address=${VAULT_ADDR} "$UNSEAL_KEY"
        echo ""
    done
}


#### Script Starts Here ####

# Set project config
VAULT_SKIP_VERIFY=true
export VAULT_ADDR=https://127.0.0.1:8200
PROJECT_ROOT=$(dirname $(cd `dirname $0` && pwd))
KEYS_FILE="${PROJECT_ROOT}/_data/keys.txt"

printf "\e[0;32m\n## Vault/Consul ##\e[0m\n\n"
printf "\e[0;31m\nHint:\e[0m If you've already run this script and just need to start compose, run \e[0m\e[0;34m'docker-compose up'\e[0m from the project root.\nYour unseal keys and root token are stored in:\e[0m\e[0;34m ${KEYS_FILE}\e[0m\n\n"

printf '\e[0;34m%-6s\e[m' "Name your project: " 
read PROJECT_NAME
# Set environment so TF can pickup the var. 
export TF_VAR_env=${PROJECT_NAME}

# Clean old files and compose projects 
printf "\e[0;31m\nPlease note: \e[0mYou should stop any running docker containers previously used with this project before attempting to clean previously used config files\n\n"
reset_local

# If you did not clean all configs etc skip starting a new compose project, configure TF backend to consul and unseal vault
case $RESET_BOOL in
    y|Y|yes|Yes) 
        # Start the new project in dettached docker 
        printf "\e[0;34m\nStarting ${PROJECT_NAME} docker-compose project detached\e[0m\n\n"
        cd ${PROJECT_ROOT}
        docker-compose -f docker-compose.yml up -d  

        # Advise we are waiting for the project to complete the startup process 
        printf "\e[0;34m\nWaiting for Vault to complete startup\e[0m\n"
        until curl https://localhost:8200/v1/status 2>/dev/null | grep -q "Vault" 
        do
            # >/dev/null 2>&1
            printf "\e[0;35m.\e[0m"
            sleep 3
        done

        # Setup terraform backend
        printf "\e[0;34m\n\nSetting TF backend to our consul cluster\e[0m\n\n"
        set_backend

        # init Vault
        vault operator init -key-shares=3 -key-threshold=2 -address=${VAULT_ADDR} > ${KEYS_FILE}

        # Unseal Vault
        printf "\e[0;34m\nUnseal keys and token stored in\e[0m ${KEYS_FILE}\n"
        sleep 2
        unseal_vault
    ;;
    n|N|No|no)
          if [[ $(vault status | awk "/Sealed/ {print \$2}") == 'true' ]];then
              sleep 2
              # Unseal Vault
              unseal_vault
          fi
    ;;
esac

# Get the vault root token and your local ip
VR_TOKEN=`cat ${PROJECT_ROOT}/_data/keys.txt | grep Initial | cut -d':' -f2 | tr -d '[:space:]'`
export VAULT_TOKEN="${VR_TOKEN}"
vault login ${VR_TOKEN} >/dev/null

# Bootstrap the vault configuration
printf "\e[0;34mDo you want to bootstap Vault? \e[0m"
read BOOTSTRAP

case $BOOTSTRAP in
y|Y|yes)
    bootstrap_vault
;;
*)
    printf "\e[0;34m\nSkipping Bootstrap\n\n\e[0m"
;;
esac

if ${PKI_ENGINE};
then
    printf "\e[0;34mVault setup complete, would you like to test dynamic cert_auth then generating a dynamic database secret? \e[0m"
    read DYNAMIC_TEST

    case ${DYNAMIC_TEST} in
    y|Y|yes)
        # Get app name
        printf "\e[0;34m\nStarting certificate genration - please enter the app name you wish to use: \e[0m"
        read APP_NAME

        # Setup AppRoles and Associated tokens
        #app_roles

        # # Setup tf orchestrator 
        orchestrator

        # #### Change dir from script starting location to terraform/orchestrator/provisioner 
        # terraform init 
        # terraform apply ## Add auto apply flag 
        # ## Take token from above command the set to var and export as VR_Token
        # # Cd to terraform/orchestrator/tls 
        # terraform init
        # terraform apply ## Add auto apply flag 
    ;;
    esac

else
    printf "\e[0;34m\nVault setup complete, re-run script at anytime to update config or bootstrap further\e[0m\n"
fi