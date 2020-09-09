#!/bin/bash

# Colors:
# red=$'\e[1;31m'
# grn=$'\e[1;32m'
# yel=$'\e[1;33m'
# blu=$'\e[1;34m'
# mag=$'\e[1;35m'
# cyn=$'\e[1;36m'
# end=$'\e[0m'

## Script designed to automate the setup of this entire project. 

function build_certs(){

    
    IFIP=`ifconfig | awk '/broadcast/{print $2}'`
    printf "authorityKeyIdentifier=keyid,issuer\nbasicConstraints=CA:FALSE\nkeyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment\nsubjectAltName = @alt_names\n[alt_names]\nDNS.1 = localhost\nIP.1 = ${IFIP}\nIP.2 = 127.0.0.1" > domains.ext
    printf '\e[1;34m%-6s\e[m' "Name your project env: " 
    read PROJECT_NAME 
    printf "\n\n"

    sh ./create_local_certs.sh $PROJECT_NAME
    cp ./{localhost.crt,localhost.key,$PROJECT_NAME.pem} ./config

    printf "\e[1;34mAdding new cert to keychain and setting as 'Always Trust - Please enter your 'sudo' password.\e[0m\n\n'"
    sudo /usr/bin/security -v add-trusted-cert -r trustAsRoot -e hostnameMismatch -d -k /Library/Keychains/System.keychain ./config/localhost.crt
}

function clean_local(){
    printf "\e[1;34m\nShould this script stop your previous compose project? \e[0m"
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

    printf "\e[1;34m\nShould previously used files be removed before starting this build? i.e consul data, apps, orchestrator: \e[0m "
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
   printf '\e[1;34m%-6s\e[m' "Should we generate new certs for this project? "
   read CERTS_BOOL
   
    case $CERTS_BOOL in 
    y|Y|yes)
        rm -f $pwd/config/*.crt $pwd/config/*.key 
        build_certs
    ;;
    n|N|No)
    ;;
    *)
        printf "\n Invalid section, please use the format 'Y|N'\n\n"
        clean_local
    ;;
    esac
}

#### Script Starts Here ####

printf "\e[1;32m\n## Vault local dev quick start ##\e[0m\n"
printf "\e[1;32m\nHint: If you've already run this script and just need to start compose - run 'docker-compose up' from the project root\e[0m\n\n"
printf "\e[1;32m\nYour unseal keys and root token are stored in ./_data/keys.txt\e[0m\n\n"

# Clean old files and compose projects 
printf "\e[0;31mPlease note: \e[0mYou should stop any running docker containers previously used with this project before attempting to clean old files\n\n"
clean_local

# Certiicate check
if [ -z ${PROJECT_NAME} ];then
    printf '\e[1;34m%-6s\e[m' "Name your project env: " 
    read PROJECT_NAME

    if ls ./config | grep -q 'localhost.crt' && ls ./config | grep -q 'localhost.key' && ls ./config | grep -q ".pem";then

        printf "\e[1;34m%-6s\nProject SSL Certs found, using the following files: \e[m\n\n"
        ls ./config | grep "localhost.crt\|localhost.key\|.pem"

        printf "\e[1;34m%-6s\nIf you did not use this script to generate your certs, please open the localhost.crt certificate you created and verify it is set to 'Always Trust' in your keychain.\e[m"
        printf "\e[1;34m%-6s\n\nOpen Keychain now? \e[0m"
        read KEYCHAIN

        case $KEYCHAIN in
        y|Y|yes)
            printf "\e[0;31m\nNote:\e[0m Opening keychain - if you generated a new cert, look for the cert that expires 3 years from the time you ran this script, double click, then hit the 'trust' drop-down and choose: 'Always Trust'"
            # Open KeyChain
            open /Library/Keychains/System.keychain
            printf "\n\e[1;34m%-6s\nPress any key to continue...\e[m\n"
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
            printf "\n Exiting, please add certs to continue...\n\n"
            exit 0
        ;;
        esac 
    fi
fi

case $CLEAN_BOOL in
y|Y|yes|Yes)
    # # Run Docker Comose to build our project
    rm -f screenlog.0
    screen -L -S local-vault -d -m docker-compose -f docker-compose.yml up
    printf "\e[1;34m%-6s\nDetached screen started with docker-compse\nView the full log at anytime via the project_root/screenlog.0\nTo attach to this screen at any time run 'screen -r'\e[0m\n\n"

    # # View running screen with or docker containers
    screen -ls 

    printf "\e[1;34m%-6s\nWaiting for containers to complete startup\e[0m\n\n"
    until cat screenlog.0 | grep -q "Vault server started!"
    do
        sleep 5
    done

    # # Unsealing the vault 
    # sh unseal.sh &2>/dev/null 
    printf "\e[1;34m\nUnseal keys and token stored in '_data/keys.txt'\e[0m\n"
    export VAULT_ADDR=https://localhost:8200
    sleep 3

    # # Setup terraform backend
    printf "\e[1;34m\nSetting TF backend to our consul cluster\e[0m\n\n"
    sh ./terraform/set_backend.sh true
;;
n|N|No|no)
;;
esac

# Unseal vault 
sh unseal.sh

# # Get the vault root token and your local ip
VR_TOKEN=`cat ./_data/keys.txt | grep Initial | cut -d':' -f2`

# Bootstrap the vault configuration
sh bootstrap_vault.sh ${VR_TOKEN} ${PROJECT_NAME}

# Setup AppRoles and Associated tokens
sh apps.sh ${VR_TOKEN}

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