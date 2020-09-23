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

function build_certs(){
    # Get local ip address and add it to our certificate request 
    IFIP=`ifconfig | awk '/broadcast/{print $2}'`
    printf "authorityKeyIdentifier=keyid,issuer\nbasicConstraints=CA:FALSE\nkeyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment\nsubjectAltName = @alt_names\n[alt_names]\nDNS.1 = localhost\nIP.1 = ${IFIP}\nIP.2 = 127.0.0.1" > domains.ext

    # Generate the project certificates
    cd ${PROJECT_ROOT}/config
    # Genrating CA
    printf "\e[0;34m\nGenerating CA Certs\e[0m\n\n"
    openssl req -x509 -nodes -new -sha256 -days 1024 -newkey rsa:2048 -keyout ${PROJECT_NAME}.key -out ${PROJECT_NAME}.pem -subj "/C=US/ST=YourState/L=YourCity/O=Example-Certificates/CN=localhost.local"
    openssl x509 -outform pem -in ${PROJECT_NAME}.pem -out ${PROJECT_NAME}.crt
    # Generating Vault/Consul certificates
    printf "\e[0;34mGenerating Vault/Consul Certs\e[0m\n\n"
    openssl req -new -nodes -newkey rsa:2048 -keyout localhost.key -out localhost.csr -subj "/C=US/ST=YourState/L=YourCity/O=Example-Certificates/CN=localhost.local"
    openssl x509 -req -sha256 -days 1024 -in localhost.csr -CA ${PROJECT_NAME}.pem -CAkey ${PROJECT_NAME}.key -CAcreateserial -extfile ${PROJECT_ROOT}/domains.ext -out localhost.crt

    # Add new localhost.crt to your keychain as 'Always Trusted'
    printf "\e[0;34m\nAdding new cert to keychain and setting as 'Always Trust - If prompted, please enter your 'sudo' password below.\e[0m\n\n'"
    sudo /usr/bin/security -v add-trusted-cert -r trustAsRoot -e hostnameMismatch -d -k /Library/Keychains/System.keychain localhost.crt >/dev/null 2>&1
    cd ${PROJECT_ROOT}
}

function cert_check() {
    # Certiicate check
    if ls ${PROJECT_ROOT}/config/ | grep -q 'localhost.crt' && ls ${PROJECT_ROOT}/config | grep -q 'localhost.key';then

        printf "\e[0;34m\nCluster Certs found, using the following files: \e[m\n\n"
        ls ${PROJECT_ROOT}/config | grep "localhost.crt\|localhost.key\|.pem"

        # Verify localhost.crt is added to our keychain
        if security export -k /Library/Keychains/System.keychain -t certs | grep -q `cat ${PROJECT_ROOT}/config/localhost.crt | sed '/^-.*-$/d' | head -n 1`; then
            printf "\e[0;34m\nCert found in keychain\e[0m\n"
        else
            printf "\e[0;34m\nCert not found in keychain, adding now as 'Always Trusted'\e[0m"
            sudo /usr/bin/security -v add-trusted-cert -r trustAsRoot -e hostnameMismatch -d -k /Library/Keychains/System.keychain localhost.crt >/dev/null 2>&1
        fi
    else 
        printf "Cert files not found in '${PROJECT_ROOT}/config', please add the following for use within the vault/consul cluster: localhost.key, localhost.crt\n"
        read -p "Instead, would you like to generate new certs now? " CERTS_BOOL

        case $CERTS_BOOL in 
        y|Y|yes)
            build_certs
        ;;
        n|N|No)
            printf "\n Exiting, please add certs and restart this script or use the gernate certs option...\n\n"
            exit 0
        ;;
        esac 
    fi
}

# Function to delete all local terraform/vault/consul configs used
function reset_local(){
    printf "\e[0;34m\nShould this script stop your previous Mimir docker-compose project? \e[0m"
    read STOP_COMPOSE
    
    # If true, stop any docker-compose projects built with this project.
    case $STOP_COMPOSE in
    y|Y|yes)
        docker-compose down
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
        rm -rf ${PROJECT_ROOT}/_data
        rm -rf ${PROJECT_ROOT}/localhost.crt ${PROJECT_ROOT}/localhost.key
        echo "Clearing apps, consul, orchestrator"
        for directory in ${PROJECT_ROOT}/terraform/*; do
          if [[ -d "${directory}" ]]; then
             echo "deleting ${directory}/.terraform"
             rm -rf ${directory}/.terraform
             echo "deleting terraform.tfstate.d"
             rm -rf ${directory}/terraform.tfstate.d
             echo "deleting terraform.tfstate"
             rm -rf ${directory}/terraform.tfstate
             echo "deleting terraform.tfstate.backup"
             rm -rf ${directory}/terraform.tfstate.backup
             echo "delete backends"
             rm -rf ${directory}/backend.tf
          fi
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
        rm -f ${PROJECT_ROOT}/config/*.crt ${PROJECT_ROOT}/config/*.key 
        build_certs
    ;;
    n|N|no)
        cert_check
    ;;
    esac
}

function set_backend(){
    for directory in ${PROJECT_ROOT}/terreaform/*; do
      if [[ -d "${directory}" ]]; then
         if [[ ${directory} == *tls* ]] || [[ ${directory} == *provisioner* ]] || [[ ${directory} == *orchestrator* ]] || [[ ${directory} == *bootstrap* ]]; then
           continue
         else
           rm -rf backend.tf
           folder=$(echo ${directory} | awk -F "/" '{print $NF}')
           echo "FOLDER SHOULD BE : ${folder}"
           echo "setting ${directory}/backend.tf"
           if [ "${LOCAL}" == "true" ]; then
             echo "Setting Consul Backend local"
             echo "terraform {
                    backend \"consul\" {
                      path = \"vault/${folder}\"
                    }
                  }" > ${directory}/backend.tf
           elif [ "$LOCAL" != "true" ]; then
             echo "Setting Consul Backend artifactory"
             echo "terraform {
                    backend \"artifactory\" {
                      subpath = \"vault/tfvars\"
                    }
                  }" > ${directory}/backend.tf
           fi
        fi
      fi
    
    done
}
#### Script Starts Here ####

# change to project root and set basic vars
cd ../
PROJECT_ROOT="${PWD}"
KEYS_FILE="${PROJECT_ROOT}/_data/keys.txt"

printf "\e[0;32m\n## Vault/Consul ##\e[0m\n\n"
printf "\e[0;31m\nHint:\e[0m If you've already run this script and just need to start compose, run \e[0m\e[0;34m'docker-compose up'\e[0m from the project root. Your unseal keys and root token are stored in:\e[0m\e[0;34m ${KEYS_FILE}\e[0m\n\n"

printf '\e[0;34m%-6s\e[m' "Name your project: " 
read PROJECT_NAME 

# Clean old files and compose projects 
printf "\e[0;31m\nPlease note: \e[0mYou should stop any running docker containers previously used with this project before attempting to clean old files\n\n"
reset_local

# If you did not clean all configs etc skip starting a new compose project, configure TF backend to consul and unseal vault
case $RESET_BOOL in
  y|Y|yes|Yes) 
      # Remove previous screen logs 
      rm -f screenlog.* >/dev/null 2>&1
      screen -L -S local-vault -d -m docker-compose -f docker-compose.yml up
      PID=`screen -ls | awk -F'.' "/local-vault/ {print \$1}"`
      printf "\e[0;34m\nStarting ${PROJECT_NAME} docker-compse project in a detached screen\n\nView the full log at anytime via\e[0m ${PWD}/screenlog.0\e[0m\n"
      printf "\e[0;34m\nTo attach to this screen at any time run\e[0m `screen -r ${PID}`\n\n"
      
       
      # Advise we are waiting for the project to complete the startup process 
      printf "\e[0;34m\nWaiting for containers to complete startup\e[0m\n"
      until cat screenlog.0 | grep -q "Vault server started!"
      do
          sleep 1
          printf "\e[0;35m.\e[0m" 
      done
  
      # Setup terraform backend
      printf "\e[0;34m\n\nSetting TF backend to our consul cluster\e[0m\n\n"
      sleep 3
      set_backend
  
      export VAULT_SKIP_VERIFY=true
      export VAULT_ADDR=https://localhost:8200
  
      # init Vault
      vault operator init -key-shares=3 -key-threshold=2 -address=${VAULT_ADDR} > ${KEYS_FILE}
      export VAULT_TOKEN=$(cat ${KEYS_FILE} | awk '/Root Token:/{print substr($4, 1, length($4)-1)}')
  
      printf "\e[0;34m\nUnseal keys and token stored in ${KEYS_FILE}\e[0m\n"
      sleep 3
  
      # Unseal Vault
      printf "\e[0;34m\nAttempting unseal process now...\n\n\e[0m"
      for i in $(cat ${KEYS_FILE} | awk "/Unseal Key/ {print \$4}"); do
          UNSEAL_KEY=${i}
          vault operator unseal -address=${VAULT_ADDR} "$UNSEAL_KEY"
      done
  
  ;;
  n|N|No|no)
      if [[ $(vault status | awk "/Sealed/ {print \$2}") == 'true' ]];then
          printf "\e[0;34m\nUnsealing Vault...\e[0m\n"
          for i in $(cat ${KEYS_FILE} | awk "/Unseal Key/ {print \$4}"); do
          UNSEAL_KEY=${i}
          vault operator unseal -address=${VAULT_ADDR} "$UNSEAL_KEY"
          done
      fi
  ;;
esac

# Get the vault root token and your local ip
VR_TOKEN=`cat ./_data/keys.txt | grep Initial | cut -d':' -f2`

# Bootstrap the vault configuration
printf "\e[0;34m\nDo you want to bootstap Vault? \e[0m"
read BOOTSTRAP

case $BOOTSTRAP in
y|Y|yes)
    sh bootstrap_vault.sh ${VR_TOKEN} ${PROJECT_NAME}
;;
*)
    printf "\e[0;34m\nSkipping Bootstrap\n\e[0m"
;;
esac

# Setup AppRoles and Associated tokens
#sh apps.sh ${VR_TOKEN}

# # Setup tf orchestrator 
# ## Check to make sure responce 200 fromt this command
# python parse_certs.py -T ${VR_TOKEN} -U "https://localhost:8200" -C localhost

# #### Change dir from script starting location to terraform/orchestrator/provisioner 
# terraform init 
# terraform apply ## Add auto apply flag 
# ## Take token from above command the set to var and export as VR_Token
# # Cd to terraform/orchestrator/tls 
# terraform init
# terraform apply ## Add auto apply flag 


# Verify all certs are created and 