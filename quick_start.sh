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

    
    IFIP=`ifconfig | awk '/broadcast/{print $2}'`
    printf "authorityKeyIdentifier=keyid,issuer\nbasicConstraints=CA:FALSE\nkeyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment\nsubjectAltName = @alt_names\n[alt_names]\nDNS.1 = localhost\nIP.1 = ${IFIP}\nIP.2 = 127.0.0.1" > domains.ext
    printf '\e[0;34m%-6s\e[m' "Name your project env: " 
    read PROJECT_NAME 
    printf "\n\n"

    sh ./create_local_certs.sh $PROJECT_NAME
    cp ./{localhost.crt,localhost.key,$PROJECT_NAME.pem} ./config

    printf "\e[0;34mAdding new cert to keychain and setting as 'Always Trust - Please enter your 'sudo' password.\e[0m\n\n'"
    sudo /usr/bin/security -v add-trusted-cert -r trustAsRoot -e hostnameMismatch -d -k /Library/Keychains/System.keychain ./config/localhost.crt
}

function clean_local(){
    printf "\e[0;34m\nShould this script stop your previous compose project? \e[0m"
    read STOP_COMPOSE
    
    case $STOP_COMPOSE in
    y|Y|yes)
        docker-compose down
    ;;
    n|N|no)
    ;;
    *)
        printf "\n Invalid section, please use the format 'Y|N'\n\n"
        clean_local
    esac

    printf "\e[0;34m\nShould previously used files be removed before starting this build? i.e consul data, apps, orchestrator: \e[0m "
    read CLEAN_BOOL

    case $CLEAN_BOOL in 
    y|Y|yes)
        sh reset-local.sh
    ;;
    n|N|No)
    ;;
    *)
        printf "\n Invalid section, please use the format 'Y|N'\n\n"
        clean_local
    ;;
    esac
 
   printf "\n\e[0;31mWarning: this will remove all cert files in ${PWD}/config\e[0m \n"
   printf '\e[0;34m%-6s\e[m' "Should we generate new certs for this project? "
   read CERTS_BOOL
   
    case $CERTS_BOOL in 
    y|Y|yes)
        rm -f $pwd/config/*.crt $pwd/config/*.key 
        build_certs
    ;;
    n|N|no)
    ;;
    *)
        printf "\n Invalid section, please use the format 'Y|N'\n\n"
        clean_local
    ;;
    esac
}

#### Script Starts Here ####
KEYS_FILE='_data/keys.txt'
printf "\e[0;32m\n## Vault/Consul ##\e[0m\n\n"
printf "\e[0;31m\nHint:\e[0m If you've already run this script and just need to start compose, run \e[0m\e[0;34m'docker-compose up'\e[0m from the project root. Your unseal keys and root token are stored in:\e[0m\e[0;34m ${KEYS_FILE}\e[0m\n\n"

# Clean old files and compose projects 
printf "\e[0;31mPlease note: \e[0mYou should stop any running docker containers previously used with this project before attempting to clean old files\n\n"
clean_local

# Certiicate check
if [ -z ${PROJECT_NAME} ];then
    
    if ls ./config | grep -q 'localhost.crt' && ls ./config | grep -q 'localhost.key' && ls ./config | grep -q ".pem";then

        printf "\e[0;34m%-6s\nProject SSL Certs found, using the following files: \e[m\n\n"
        ls ./config | grep "localhost.crt\|localhost.key\|.pem"
        
        PROJECT_NAME=`ls | grep ".pem" | awk -F'.' '{print $1}'`

        printf "\e[0;34m%-6s\nIf you did not use this script to generate your certs, please open the localhost.crt certificate you created and verify it is set to 'Always Trust' in your keychain. \e[0m"
        printf "\n\e[0;34m\nOpen Keychain now? \e[0m"
        read KEYCHAIN

        case $KEYCHAIN in
        y|Y|yes)
            printf "\e[0;31m\nNote:\e[0m Opening keychain - if you generated a new cert, look for the cert that expires 3 years from the time you ran this script, double click, then hit the 'trust' drop-down and choose: 'Always Trust'\e[0m"
            # Open KeyChain
            open /Library/Keychains/System.keychain
            printf "\e[0;34m\nPress any key to continue...\e[m\n"
            read  -n 1 I
        ;;
        *)
        ;;
        esac

    else 
        printf "Cert files not found, please move the cert.key, cert.crt into the ./config dir for use within this project \n"
        read -p "Instead, would you like to generate new certs now? " CERTS_BOOL

        case $CERTS_BOOL in 
        y|Y|yes)
            build_certs
        ;;
        n|N|No)
            printf "\n Exiting, please add certs and restart this script...\n\n"
            exit 0
        ;;
        esac 
    fi
fi

# If you did not clean all configs etc skip starting a new compose project, configure TF backend to consul and unseal vault
case $CLEAN_BOOL in
y|Y|yes|Yes)
    # Run Docker Comose to build our project
    rm -f screenlog.0
    screen -L -S local-vault -d -m docker-compose -f docker-compose.yml up

    PID=`screen -ls | awk -F'.' "/local-vault/ {print \$1}"`
    printf "\e[0;34m\nDetached screen started with docker-compose\n\nView the full log at anytime via\e[0m ${PWD}/screenlog.0\n\nTo attach to this screen at any time run 'screen -r ${PID}'\e[0m\n\n"

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
    sh ./terraform/set_backend.sh true

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