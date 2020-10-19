#!/bin/bash

# Colors:
# red=$'\e[1;31m'
# grn=$'\e[0;32m'
# yel=$'\e[1;33m'
# blu=$'\e[0;34m'
# mag=$'\e[1;35m'
# cyn=$'\e[1;36m'
# end=$'\e[0m'


## Add a check for vault and terraform installed locally
## Add in Pauses requesting use to hit enter to continue in key areas
## Delete app folders from /config to ensure no previous certs exist as well as directories are deleted.
## Cleanup pki function output from this script


## Script designed to automate the setup of this entire project.
function app_policies(){
    # Function to create policies for apps and databases
    printf "\e[0;34m\n\nCreating ${APP_NAME} application policies with new token\e[0m\n\n"
    sleep 3

    cd ${PROJECT_ROOT}/terraform/apps
    terraform init >/dev/null
    terraform apply -var="token=${PROVISIONER_TOKEN}" -var="app=${APP_NAME}"
    cd - >/dev/null 2>&1

}

function approle_login(){
    # Change into the appRole bootstrap dir and get the output of the fetch-token created
    printf "\e[0;34m\n\nGetting AppRole Fetch Token TF State\e[0m\n"
    cd ${PROJECT_ROOT}/terraform/vault/bootstrap/appRole_auth 2>/dev/null
    FETCH_TOKEN=`terraform output -json appRole_fetch_token | tr -d '"'`
    #echo ${FETCH_TOKEN}
    cd - >/dev/null

    # With the new fetch token get the role-id and secret-id
    ROLE_ID=`curl --silent --header "X-Vault-Token: ${FETCH_TOKEN}" https://127.0.0.1:8200/v1/auth/approle/role/${APP_NAME}/role-id | awk -F'"' '{print $18}'`
    SECRET_ID=`curl --silent -X POST --header "X-Vault-Token: ${FETCH_TOKEN}" https://127.0.0.1:8200/v1/auth/approle/role/${APP_NAME}/secret-id | awk -F'"' '{print $18}'`
    printf "\e[0;34m\nRole-ID:\e[0m ${ROLE_ID}\n"
    printf "\e[0;34mRole-ID:\e[0m ${SECRET_ID}\n"

    # Now, renew your fetch token so it can be used when you next deploy
    RENEWED_FETCH=`curl --silent -X POST --header 'X-Vault-Token: ${FETCH_TOKEN}' https://127.0.0.1:8200/v1/auth/token/renew`

    # Login with your role_id and secret_id
    APPROLE_TOKEN=`curl --silent -H "Content-Type: application/json" -d "{\"role_id\": \"${ROLE_ID}\",\"secret_id\":\"${SECRET_ID}\"}" -X POST https://127.0.0.1:8200/v1/auth/approle/login | awk -F'{' '{print $3}' | awk -F':' '{print $2}' | awk -F',' '{print $1}' | tr -d '"'`
    printf "\e[0;34m\n${APP_NAME}-token:\e[0m ${APPROLE_TOKEN}\n"


}

function bootstrap_vault(){
    # Function to bootstrap vault with terraform

    printf "\e[0;34m\n\nStarting Bootstrap\n\n"

    for DIR in $(find ${PROJECT_ROOT}/terraform/vault/bootstrap/ -type d -mindepth 1 -maxdepth 1 | sed s@//@/@ | sort); do
        printf "\e[0;34m\nPATH:\e[0m $DIR\n"
        MODULE="$(basename $(dirname ${DIR}/backend.tf))"

        printf "\e[0;34mModule:\e[0m $MODULE\n"
        printf "\e[0;34m\nShould TF bootstrap this module? \e[0m"
        read TO_BOOTSTRAP

        case $TO_BOOTSTRAP in
        y|Y|yes)
         cd ${DIR}
         terraform init -backend-config="${PROJECT_ROOT}/config/local-backend-config.hcl" >/dev/null
         terraform apply -var="vault_token=${VR_TOKEN}" -var="vault_addr=${VAULT_ADDR}" -var="env=${PROJECT_NAME}"
         if [ ${MODULE} == "cert_auth" ]
         then
            printf "\e[1;32mCerts: [\n${PROJECT_ROOT}/config/${PROJECT_NAME}.crt\n${PROJECT_ROOT}/config/${PROJECT_NAME}.key\n]\n"
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
    # Get local docker network ip address and add it to our certificate request 
    IFIP=`ifconfig en0 | awk '/broadcast/{print $2}'`
    printf "authorityKeyIdentifier=keyid,issuer\nbasicConstraints=CA:FALSE\nkeyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment\nsubjectAltName = @alt_names\n[alt_names]\nDNS.1 = localhost\nIP.1 = ${IFIP}\nIP.2 = 127.0.0.1" > ${PROJECT_ROOT}/config/domains.ext

    # Generate the project certificates
    mkdir -p ${PROJECT_ROOT}/config/cluster_certs >/dev/null 2>&1
    cd ${PROJECT_ROOT}/config/cluster_certs
    rm -f *.pem *.crt *.key *.csr *.srl

    # Genrating CA
    printf "\e[0;34m\n\nGenerating CA Certs\e[0m\n\n"
    openssl req -x509 -nodes -new -sha256 -days 1024 -newkey rsa:4096 -keyout ${PROJECT_NAME}.key -out ${PROJECT_NAME}.pem -subj "/C=US/ST=YourState/L=YourCity/O=${PROJECT_NAME}/CN=localhost.local"
    openssl x509 -outform pem -in ${PROJECT_NAME}.pem -out ${PROJECT_NAME}.crt

    printf "\e[0;34m\nSelf-signed Project certs created, these can be assigned to a cert auth role and referenced on login.\e[0m\n\n"
    printf "${PWD}:\n"
    ls ${PROJECT_ROOT}/config | grep "${PROJECT_NAME}.crt\|${PROJECT_NAME}.key"

    # Generating Vault/Consul certificates
    printf "\e[0;34m\nGenerating Vault/Consul Certs\e[0m\n\n"
    openssl req -new -nodes -newkey rsa:4096 -keyout localhost.key -out localhost.csr -subj "/C=US/ST=YourState/L=YourCity/O=${PROJECT_NAME}/CN=localhost.local"
    openssl x509 -req -sha256 -days 1024 -in localhost.csr -CA ${PROJECT_NAME}.pem -CAkey ${PROJECT_NAME}.key -CAcreateserial -extfile ${PROJECT_ROOT}/config/domains.ext -out localhost.crt

    # Add new localhost.crt to your keychain as 'Always Trusted'
    printf "\e[0;34m\nAdding new self-signed localhost cert to keychain and setting as 'Always Trust - If prompted, please enter your 'sudo' password below.\e[0m\n\n'"
    sudo /usr/bin/security -v add-trusted-cert -r trustAsRoot -e hostnameMismatch -d -k /Library/Keychains/System.keychain localhost.crt >/dev/null 2>&1
    cd - >/dev/null 2>&1
}

function demos(){
    printf "\e[0;34mNext, you can choose a demo to run from the list: \e[0m\n\n"
    printf "  1. Dynamic Database Secerts with TLS Auth\n"
    printf "  2. Dynamic Database Secerts with AppRole Auth\n"
    printf "  3. Exit\n\n"
    read -p ":" DEMO

    case ${DEMO} in
    1)
        # Make sure both the pki engine and cert auth methods are configured
        SET_PKI=`curl --write-out '%{http_code}' --silent --header "X-Vault-Token: ${VR_TOKEN}" https://127.0.0.1:8200/v1/pki_int/config | grep '200' >/dev/null`
        SET_CERTS=`curl --write-out '%{http_code}' --silent --header "X-Vault-Token: ${VR_TOKEN}" https://127.0.0.1:8200/v1/cert/config | grep '200' >/dev/null`

        # If the PKI Secret engine was bootstrapped - ask if we should test dynamic cert auth with dynamic secrets
        if ${SET_PKI} || ${SET_CERTS};
        then
            printf "\e[0;34m\nThis demo can walk you through the dynamic CI/CD Auth process as if you were an application, the process is:\n\e[0m"
            printf "    1. Generate a Provisoner Token with permission to create tokens, roles, and policies\n"
            printf "    2. Create Application specific policies\n"
            printf "    3. Generate a app certificates via the PKI engine\n"
            printf "    4. Create a Cert(TLS) Auth role\n"
            printf "    5. Generate a database username and password via the bootstraped mssql enable\n"
            printf "    6. As the app, login with the new TLS certs to generate a token\n"
            printf "    7. Use your new token to generate database creds\n"
            printf "    8. Login to the database with your new creds\n\n"

            # Get app name
            printf "\e[0;34m\nUse appRole as entered during appRole bootstrap? \e[0m"
            read READ_APP_NAME

            case $READ_APP_NAME in
            y|Y|yes)
                # Change into the appRole bootstrap dir and get the output of the fetch-token created
                cd ${PROJECT_ROOT}/terraform/vault/bootstrap/appRole_auth 2>/dev/null 
                APP_NAME=`terraform output -json role_name | tr -d '"'`
                printf "\e[0;34mUsing Name:\e[0m ${APP_NAME}\n\n"
                cd - >/dev/null
            ;;
            n|N|no)
                printf "\e[0;34m\nEnter the app name you would like to use: \e[0m"
                read APP_NAME
            ;;
            esac

            # Setup tf orchestrator a.k.a master token for provisioning
            orchestrator

            # Change into the app specific configuration directory
            cd ${PROJECT_ROOT}/config/${APP_NAME}
            APP_DIR=`pwd`

            # Generate new certs for the app cert authentication
            printf "\e[0;34m\nWith Provisioner Token, creating application certs in:\e[0m ${PROJECT_ROOT}/config/${APP_NAME}\n\n"
            python ${PROJECT_ROOT}/terraform/orchestrator/vault_cert_gen.py -T ${PROVISIONER_TOKEN} -U "https://localhost:8200" -C "${APP_NAME}.com" -TTL "1h"
            cd - >/dev/null 2>&1

            ls -lah ${PROJECT_ROOT}/config/${APP_NAME} | grep '.crt\|.pem' | awk -F' ' '{print $9}'

            printf "\e[0;34m\nPress any key to continue\e[0m"
            read -n 1 -s -r

            # Create new role and tie it to our newly gerenated appliction certs
            cd ${PROJECT_ROOT}/terraform/orchestrator/tls
            printf "\e[0;34m\n\nCreating Cert Auth Role with the Master Provisioner Token and newly created application TLS certs.\n\n"
            sleep 3
            terraform init >/dev/null
            terraform apply -var="app=${APP_NAME}" -var="vault_token=${PROVISIONER_TOKEN}"
            cd - >/dev/null

            printf "\e[0;34m\nPress any key to continue\e[0m\n"
            read -n 1 -s -r

            # Create demo db config
            create_db_connection

            # Ask if they would like to test cert auth
            dynamic_cert_login

            # Call dynamic database login function
            dynamic_db_login ${CERT_TOKEN}

        else
            printf "\e[0;34m\nEither PKI Engine, Cert Auth, or MSSQL not bootstrapped, please restart this script and complete that process.\e[0m\n"
            exit 0
        fi
    ;;
    2)
        # Make sure both the pki engine and cert auth methods are configured
        SET_PKI=`curl --write-out '%{http_code}' --silent --header "X-Vault-Token: ${VR_TOKEN}" https://127.0.0.1:8200/v1/pki_int/config | grep '200' >/dev/null`
        SET_DB=`curl --write-out '%{http_code}' --silent --header "X-Vault-Token: ${VR_TOKEN}" https://127.0.0.1:8200/v1/mssql/config/${APP_NAME} | grep '200' >/dev/null`

        # If the PKI Secret engine was bootstrapped - ask if we should test dynamic cert auth with dynamic secrets
        if ${SET_PKI} || ${SET_DB};
        then
            printf "\e[0;34m\nThis demo can walk you through the dynamic CI/CD Auth process as if you were an application, the process is:\n\e[0m"
            printf "    1. Generate a Provisoner Token with permission to create tokens, roles, and policies\n"
            printf "    2. Create Application specific policies\n"
            printf "    5. Create a database connection\n"
            printf "    6. As the app, use fetch token to get appRole role and secret ids, then login to get app token\n"
            printf "    7. Use your new appRole token to generate database creds\n"
            printf "    8. Login to the database with your new creds\n\n"

            # Get app name
            printf "\e[0;34m\nUse appRole as entered during appRole bootstrap? \e[0m"
            read READ_APP_NAME

            case $READ_APP_NAME in
            y|Y|yes)
                # Change into the appRole bootstrap dir and get the output of the fetch-token created
                cd ${PROJECT_ROOT}/terraform/vault/bootstrap/appRole_auth 2>/dev/null 
                APP_NAME=`terraform output -json role_name | tr -d '"'`
                printf "\e[0;34mUsing Name:\e[0m ${APP_NAME}\n\n"
                cd - >/dev/null
            ;;
            n|N|no)
                printf "\e[0;34m\nEnter the app name you would like to use: \e[0m"
                read APP_NAME
            ;;
            esac

            # Setup tf orchestrator a.k.a master token for provisioning
            orchestrator

            printf "\e[0;34m\nPress any key to continue\e[0m\n"
            read -n 1 -s -r

            # Create demo db config
            create_db_connection

            # AppRole Login
            approle_login

            # Call dynamic database login function
            dynamic_db_login ${APPROLE_TOKEN}
        else
            printf "\e[0;34m\nEither PKI Engine or Cert Auth not bootstrapped, please restart this script and complete that process.\e[0m\n"
            exit 0
        fi
    ;;
    3)
        exit 0
    ;;
    esac
}

function cluster_cert_check() {
    # Certiicate check
    if ls ${PROJECT_ROOT}/config/cluster_certs | grep -q 'localhost.crt' && ls ${PROJECT_ROOT}/config/cluster_certs | grep -q 'localhost.key';then

        printf "\e[0;34m\nCluster Certs found, using the following files: \e[0m\n\n"
        ls ${PROJECT_ROOT}/config/cluster_certs | grep "localhost.crt\|localhost.key"

        # Verify localhost.crt is added to our keychain
        if security export -k /Library/Keychains/System.keychain -t certs | grep -q `cat ${PROJECT_ROOT}/config//cluster_certs/localhost.crt | sed '/^-.*-$/d' | head -n 1`; then
            printf "\e[0;34m\nCert found in your local Keychain\e[0m\n\n"
        else
            printf "\e[0;34m\nCert not found in keychain, adding now as 'Always Trusted'\e[0m"
            sudo /usr/bin/security -v add-trusted-cert -r trustAsRoot -e hostnameMismatch -d -k /Library/Keychains/System.keychain localhost.crt >/dev/null 2>&1
        fi
    else
        printf "\n\e[0;34mCert files not found in:\e[0m ${PROJECT_ROOT}/config/cluster_certs. (localhost.key, localhost.crt)\e[0;34m\n\nThese are needed for use within the vault/consul cluster\e[0m\n"
        printf "\n   1. Build Certs\n"
        printf "\n   2. Add my own certs\n"
        read -p ": " CERTS_CHECK


        case $CERTS_CHECK in
        1)
            build_local_certs
        ;;
        2)
            printf "\e[0;34m\nOnce certs are in place - Press any key to continue\e[0m"
            read -n 1 -s -r
            cluster_cert_check
        ;;
        esac
    fi
}

function create_db_connection(){
    # Create database
    printf "\e[0;34m\nCreating demo ${APP_NAME} database...\e[0m\n"
    printf "\e[0;34mPlease enter db password as defined in the docker-compose file in the project root: \e[0m"
    read DB_PASSWORD
    docker exec -it mssql /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P ${DB_PASSWORD} -Q "create database ${APP_NAME};"

    # Call demo sql tf module
    printf "\e[0;34m\nCreating App database connection and role\e[0m\n"
    cd ${PROJECT_ROOT}/terraform/demo/dynamic_cert-dynamic_db_creds
    terraform init >/dev/null

    #echo "terraform apply -var=\"app=${APP_NAME}\" -var=\"vault_token=${VR_TOKEN}\" -var=\"sql_pass=${DB_PASSWORD}\" -var=\"sql_user=sa\""
    terraform apply -var="app=${APP_NAME}" -var="vault_token=${VR_TOKEN}" -var="sql_pass=${DB_PASSWORD}" -var="sql_user=sa"
    cd - >/dev/null

    # Create a database role with our master provisioner token
    export VAULT_TOKEN=${VR_TOKEN}

    printf "\e[0;34m\nCreating database role\n\e[0m"
    vault write mssql/roles/${APP_NAME}-role \
    db_name=${APP_NAME}\
    creation_statements="CREATE LOGIN [{{name}}] WITH PASSWORD = '{{password}}';\
    CREATE USER [{{name}}] FOR LOGIN [{{name}}];\
    GRANT SELECT ON SCHEMA::dbo TO [{{name}}];" \
    default_ttl="1h" \
    max_ttl="24h" \

    echo ""
    vault read mssql/roles/${APP_NAME}-role

    printf "\e[0;34m\n\nApplication auth, policies and role provisioning complete. You can now login with your pki generated certs, then grab your dynamic database password.\e[0m\n"

    printf "\e[0;34m\nPress any key to continue\e[0m"
    read -n 1 -s -r

}

function dynamic_cert_login(){
    # Function designed to take user input for cert/private key to then use for cert_auth login into Vault

    # Print to screen the vault command which will be used for cert login - then login
    printf "\e[0;34m\n\nTesting login with your new application cert and role - using the following command:\e[0m\n"
    printf "\n\nvault login -method=cert -client-cert=${PROJECT_ROOT}/config/${APP_NAME}/cert.crt -client-key=${PROJECT_ROOT}/config/${APP_NAME}/private.crt name=${APP_NAME}\n\n"
    #curl --request POST --cert ${PROJECT_ROOT}/config/${APP_NAME}/cert.crt --key ${PROJECT_ROOT}/config/${APP_NAME}/private.crt --data "{\"name\": \"${APP_NAME}\"}" https://127.0.0.1:8200/v1/auth/cert/login > ${PROJECT_ROOT}/config/${APP_NAME}/token.txt
    vault login -method=cert -client-cert=${PROJECT_ROOT}/config/${APP_NAME}/cert.crt -client-key=${PROJECT_ROOT}/config/${APP_NAME}/private.crt name=${APP_NAME} | tee ${PROJECT_ROOT}/config/${APP_NAME}/token.txt

    # Set the new token to a variable
    printf "\e[0;34m\nSetting the new token as our auth mechanism\e[0m\n\n"
    CERT_TOKEN=`cat ${PROJECT_ROOT}/config/${APP_NAME}/token.txt | awk '/-----/{getline; print $2}'`
}

function dynamic_db_login(){
    # Function to read db creds and  login to the database
    printf "\e[0;34m\nPress any key to continue\n\e[0m"
    read -n 1 -s -r

    # Get app token as passed in demo after login. Ex cert auth or approle
    TOKEN=$1

    # Get the creds for the sql database
    printf "\e[0;34m\nGenerating dynamic database credentials with our new token.\e[0m\n"
    printf "\e[0;34m\nUsing the following command:\e[0m\n curl --header 'X-Vault-Token: ${TOKEN}' https://127.0.0.1:8200/v1/mssql/creds/${APP_NAME}-role\n\n"

    curl --silent --header "X-Vault-Token: ${TOKEN}" https://127.0.0.1:8200/v1/mssql/creds/${APP_NAME}-role > ${PROJECT_ROOT}/config/${APP_NAME}/db_creds

    DYN_DB_PASS=`cat ${PROJECT_ROOT}/config/${APP_NAME}/db_creds | awk -F{ '{print $3}' | awk -F, '{print $1}' | awk -F: '{print $2}' | tr -d '"'`
    DYN_DB_USER=`cat ${PROJECT_ROOT}/config/${APP_NAME}/db_creds | awk -F{ '{print $3}' | awk -F, '{print $2}' | awk -F: '{print $2}' | tr -d '}' | tr -d '"'`

    printf "\e[0;34m\nDynamic Database Username:\e[0m ${DYN_DB_USER} \n\e[0;34mDynamic Database Password:\e[0m ${DYN_DB_PASS}\n"
    # Login to the sql database and list tables
    printf "\e[0;34m\nPress any key to continue\n\e[0m"
    read -n 1 -s -r
    printf "\e[0;34m\nTesting login into the MSSQL database with the command below:\e[0m\n\n"
    printf "docker exec -it mssql /opt/mssql-tools/bin/sqlcmd -S localhost -U ${DYN_DB_USER} -P ${DYN_DB_PASS} -Q 'select name from sys.databases;'\n\n"
    docker exec -it mssql /opt/mssql-tools/bin/sqlcmd -S localhost -U $DYN_DB_USER -P $DYN_DB_PASS -Q 'select name from sys.databases;'
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

    # Make the application config directory
    if ! ls ${PROJECT_ROOT}/config/${APP_NAME} >/dev/null 2>&1;
    then
        mkdir ${PROJECT_ROOT}/config/${APP_NAME}
    else
        rm -rf ${PROJECT_ROOT}/config/${APP_NAME}
        mkdir ${PROJECT_ROOT}/config/${APP_NAME}
    fi

    # Generate a new token to use for provisioning our application
    cd ${PROJECT_ROOT}/terraform/orchestrator/provisioner >/dev/null 2>&1
    printf "\e[0;34m\n\nCreating Provisioner Token to be used when deploying from CI/CD - Using for Application:\e[0m ${APP_NAME}\n\n"
    sleep 3
    terraform init >/dev/null
    terraform apply -var="vault_token=${VR_TOKEN}"
    printf "\e[0;34m\nNote:\e[0m This token is created to ensure 'root' permissions are not given to the pipeline as well as for audit purposes\n\n"

    # Get the new token and set as the vault root token
    PROVISIONER_TOKEN=`terraform output -json master_provisioner_token | tr -d '"'`
    #echo "${PROVISIONER_TOKEN}"
    cd - >/dev/null 2>&1

    printf "\e[0;34m\nPress any key to continue\e[0m"
    read -n 1 -s -r

    # Setup App specific policies and Associated tokens
    app_policies
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
    esac

    printf "\e[0;34m\nShould all previously used files be removed?\e[0m i.e Vault and Consul data, Terraform backends, and TLS Certs? "
    read RESET_BOOL

    # If true, delete all previous terraform configs, states etc.
    case $RESET_BOOL in
    y|Y|yes)
        # Remove TF Configs
        printf "\e[0;34m\nRemoving Consul, Orchestrator, Vault and Consul data\e[0m\n"
        rm -rf ${PROJECT_ROOT}/_data
        rm -rf ${PROJECT_ROOT}/localhost.crt ${PROJECT_ROOT}/localhost.key
        for directory in $(find ${PROJECT_ROOT}/terraform -type d | sed s@//@/@); do
            find ${directory}/ -type f \( -name ".terraform" -o -name "terraform.tfstate.d" -o -name "terraform.tfstate" -o -name "terraform.tfstate.backup" -o -name "backend.tf" \) -delete
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

    ;;
    n|N|No)
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
          echo "terraform {
                 backend \"consul\" {
                   path = \"vault/${folder}\"
                 }
               }" > ${directory}/backend.tf
        fi
        printf "\e[0;35m.\e[0m"
    done
}

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
VAULT_SKIP_VERIFY=true
export VAULT_ADDR=https://127.0.0.1:8200
PROJECT_ROOT=$(dirname $(cd `dirname $0` && pwd))
KEYS_FILE="${PROJECT_ROOT}/_data/keys.txt"

# Terraform and Vault CLI check
if ! which vault >/dev/null
then
    printf "\e[0;34m\nVault not installed, please install to continue...\e[0m\n\n"
    exit 0
elif ! which terraform >/dev/null
then
    printf "\e[0;34m\nTerraform not installed, please install to continue...\e[0m\n\n"
    exit 0
fi

# Output warnings
printf "\e[0;32m\n## Vault/Consul ##\e[0m\n\n"
printf "\e[0;31m\nHint:\e[0m If you've already run this script and just need to start compose, run \e[0m\e[0;34m'docker-compose up'\e[0m from the project root.\nYour unseal keys and root token are stored in:\e[0m\e[0;34m ${KEYS_FILE}\e[0m\n\n"

# Get Project Env
printf "\e[0;34mName your project: \e[0m"
read PROJECT_NAME
PROJECT_NAME=$(echo $PROJECT_NAME | awk '{print tolower($0)}')
# Set environment so TF can pickup the var.
export TF_VAR_env=${PROJECT_NAME}


printf "\e[0;34m\nWhere would you like to start? \n\n\e[0m"
printf "   1. Start From The Begining\n"
printf "   2. Bootstrap\n"
printf "   3. Demos\n"
printf "   4. Reset local project\n"
printf "   5. Exit\n"
printf "\n: "
read MAIN_MENU

case ${MAIN_MENU} in
1)
    # Clean old files and compose projects
    printf "\e[0;31m\nPlease note: \e[0m \e[0;34mYou should stop any running docker containers used with this project before attempting to clean previously used config files.\e[0m\n"
    reset_local

    cluster_cert_check

    # Check if docker is already running with a vault image
    if ! docker ps 2>/dev/null | grep -q "vault";
    then
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

        # init Vault
        printf "\e[0;34m\n\nStarting Vault Init\n\e[0m"
        vault operator init -key-shares=3 -key-threshold=2 -address=${VAULT_ADDR} > ${KEYS_FILE}

        # Unseal Vault
        printf "\e[0;34m\nUnseal keys and token stored in\e[0m ${KEYS_FILE}\n"
        printf "\e[0;34m\nPress any key to continue\e[0m"
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
    #vault login ${VR_TOKEN} >/dev/null

    # Bootstrap the vault configuration
    printf "\e[0;34mDo you want to bootstap Vault?\e[0m i.e Create example auth methods, secret engines, and policies? "
    read BOOTSTRAP

    case $BOOTSTRAP in
    y|Y|yes)
        # Setup terraform backend
        printf "\e[0;34m\n\nCreating Terraform backend.tf for all modules - Setting to our consul cluster\e[0m\n"
        sleep 2
        set_backend
        # Start bootstrap process
        bootstrap_vault
    ;;
    *)
        printf "\e[0;34m\nSkipping Bootstrap\n\n\e[0m"
    ;;
    esac

    printf "\nBasic Vault setup complete!\n\nYou can now login to Vault with any of the auth methods bootstrapped.\n\n"

    # Run demo function
    demos
;;
2)
    if VR_TOKEN=`cat ${PROJECT_ROOT}/_data/keys.txt | grep Initial | cut -d':' -f2 | tr -d '[:space:]'`;
    then
        # Starting bootstrap
        bootstrap_vault
        # Starting Demos
        demos
    else
        printf "\e[0;34m\nRoot token not found in:\e[0m ${PROJECT_ROOT}/_data\n"
        printf "\e[0;34m\nPlease rerun this script and choose 'Start From The Begining'\n"
    fi
;;
3)
    if VR_TOKEN=`cat ${PROJECT_ROOT}/_data/keys.txt | grep Initial | cut -d':' -f2 | tr -d '[:space:]'`;
    then
        # Start Demos
        demos
    else
        printf "\e[0;34m\nRoot token not found in:\e[0m ${PROJECT_ROOT}/_data\n"
        printf "\e[0;34m\nPlease rerun this script and choose 'Start From The Begining'\n"
    fi
;;
4)
    reset_local
;;
5)
    exit 0
;;
*)
    printf "\e[0;34m\nInvalid Selection, please try again.\n\n"
    ${PROJECT_ROOT}/scripts/$(basename $0) && exit
;;
esac
