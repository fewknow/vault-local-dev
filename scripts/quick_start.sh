#!/bin/bash

## Script designed to automate the setup the Local Vault Development Project as part of the Mimir initiative. 

# Function to loop through terraform modules to bootstrap Vault. This repro provides a few default modules as examples and the demos to show you a complete Vault workflow.
function bootstrap_vault(){
    # Function to bootstrap vault with terraform

    printf "\e[0;34m\n\nStarting Bootstrap\n\n\e[0m"

    for DIR in $(find ${PROJECT_ROOT}/terraform/vault/bootstrap/ -type d -mindepth 1 -maxdepth 1 | sed s@//@/@ | sort --ignore-case); do
        printf "\e[0;34mLocation:\e[0m $DIR\n"
        MODULE="$(basename $(dirname ${DIR}/backend.tf))"

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
    done
}

# Function to build local signed certs to bring your Vault/Consul clusters online.
function build_local_certs(){
    # Get local docker network ip address and add it to our certificate request 
    IFIP=`ifconfig en0 | awk '/broadcast/{print $2}'`
    printf "authorityKeyIdentifier=keyid,issuer\nbasicConstraints=CA:FALSE\nkeyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment\nsubjectAltName = @alt_names\n[alt_names]\nDNS.1 = localhost\nDNS.2 = vault.dou.com\nIP.1 = ${IFIP}\nIP.2 = 127.0.0.1" > ${PROJECT_ROOT}/config/domains.ext

    # Generate the project certificates
    mkdir -p ${PROJECT_ROOT}/config/cluster_certs >/dev/null 2>&1
    cd ${PROJECT_ROOT}/config/cluster_certs
    rm -f *.pem *.crt *.key *.csr *.srl

    # Genrating CA
    printf "\e[0;34m\n\nGenerating CA Certs\e[0m\n\n"
    openssl req -x509 -nodes -new -sha256 -days 1024 -newkey rsa:4096 -keyout ${PROJECT_NAME}.key -out ${PROJECT_NAME}.pem -subj "/C=US/ST=YourState/L=YourCity/O=${PROJECT_NAME}/CN=localhost.local"
    openssl x509 -outform pem -in ${PROJECT_NAME}.pem -out ${PROJECT_NAME}.crt

    printf "\e[0;34m\nSelf-signed Project certs created, these can be assigned to a TLS auth role and referenced on login.\e[0m\n\n"
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

    # Add alias for vault.dou.com if it doesn't exist
    if ! grep -q "vault.dou.com" /etc/hosts;
    then
        printf "\e[0;34m\nAdding alias\e[0m 'vault.dou.com'\e[0;34m to /etc/hosts - If prompted, please enter your 'sudo' password below.\e[0m\n\n"
        sudo su - <<EOF
        echo  "# Added by vault-local-dev project" >> /etc/hosts
        echo  "127.0.0.1 vault.dou.com" >> /etc/hosts
EOF
    fi
}

# Check certs exist so the local Vault/Consul cluster will start 
function cluster_cert_check() {
    # Certiicate check
    if ls ${PROJECT_ROOT}/config/cluster_certs | grep -q 'localhost.crt' && ls ${PROJECT_ROOT}/config/cluster_certs | grep -q 'localhost.key';then

        printf "\e[0;34m\nCluster Certs found, using the following files: \e[0m\n\n"
        ls ${PROJECT_ROOT}/config/cluster_certs | grep "localhost.crt\|localhost.key"

        # Verify localhost.crt is added to our keychain
        if security export -k /Library/Keychains/System.keychain -t certs | grep -q `cat ${PROJECT_ROOT}/config/cluster_certs/localhost.crt | sed '/^-.*-$/d' | head -n 1`; then
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

# All functions relating to the demos 
function demos(){
    function app_policies(){
        # Function to create policies for apps and databases
        printf "\e[0;34m\n\nCreating\e[0m ${APP_NAME} \e[0;34mapplication policies with new token\e[0m\n\n"
        sleep 3

        cd ${PROJECT_ROOT}/terraform/apps
        terraform init >/dev/null
        terraform apply -var="token=${PROVISIONER_TOKEN}" -var="app=${APP_NAME}" -var="address=${VAULT_ADDRESS}"
        cd - >/dev/null 2>&1

        printf "\e[0;35m\nPress any key to continue\e[0m\n"
        read -n 1 -s -r
    }

    function app_certs(){
        # Change into the app specific configuration directory
        cd ${PROJECT_ROOT}/config/${APP_NAME}
        APP_DIR=`pwd`

        # Get PKI Engine path.
        cd ${PROJECT_ROOT}/terraform/vault/bootstrap/pki_secrets 
        PKI_INT_PATH=`terraform output -json pki-intermediate-path | tr -d '"'`
        # Get the TLS/Cert Auth method paths 
        cd ${PROJECT_ROOT}/terraform/vault/bootstrap/tls_auth
        CERT_INT_PATH=`terraform output -json cert_path | tr -d '"'`

        # Generate new certs for the app cert authentication
        cd ${PROJECT_ROOT}/terraform/orchestrator/tls

        printf "\e[0;34m\nWith Provisioner Token, creating application certs, then adding to a TLS role.\e[0m\n\n"
        terraform init >/dev/null

        terraform apply -var="app=${APP_NAME}" -var="vault_token=${PROVISIONER_TOKEN}" \
            -var="pki-int-path=${PKI_INT_PATH}" \
            -var="cert-path=${CERT_INT_PATH}"

        printf "\e[0;35m\nPress any key to continue\e[0m\n"
        read -n 1 -s -r

        cd - >/dev/null
    }

    function approle_login(){
        # Change into the appRole bootstrap dir and get the output of the fetch-token created
        printf "\e[0;34m\n\nUsing Fetch-Token to get role-id and secret-id \e[0m\n"
        cd ${PROJECT_ROOT}/terraform/vault/bootstrap/appRole_auth 2>/dev/null
        FETCH_TOKEN=`terraform output -json appRole_fetch_token | tr -d '"'`
        #echo ${FETCH_TOKEN}
        cd - >/dev/null

        # With the new fetch token get the role-id and secret-id
        ROLE_ID=`curl --silent --header "X-Vault-Token: ${FETCH_TOKEN}" ${VAULT_ADDRESS}/v1/auth/approle/role/${APP_NAME}/role-id | awk -F'"' '{print $18}'`
        SECRET_ID=`curl --silent -X POST --header "X-Vault-Token: ${FETCH_TOKEN}" ${VAULT_ADDRESS}/v1/auth/approle/role/${APP_NAME}/secret-id | awk -F'"' '{print $18}'`
        printf "\e[0;34m\nRole-ID:\e[0m ${ROLE_ID}\n"
        printf "\e[0;34mSECRET-ID:\e[0m ${SECRET_ID}\n"

        # Now, renew your fetch token so it can be used when you next deploy
        RENEWED_FETCH=`curl --silent -X POST --header 'X-Vault-Token: ${FETCH_TOKEN}' ${VAULT_ADDRESS}/v1/auth/token/renew`

        # Login with your role_id and secret_id
        APPROLE_TOKEN=`curl --silent -H "Content-Type: application/json" -d "{\"role_id\": \"${ROLE_ID}\",\"secret_id\":\"${SECRET_ID}\"}" -X POST ${VAULT_ADDRESS}/v1/auth/approle/login | awk -F'{' '{print $3}' | awk -F':' '{print $2}' | awk -F',' '{print $1}' | tr -d '"'`
        printf "\e[0;34m\n${APP_NAME}-token:\e[0m ${APPROLE_TOKEN}\n"
    }

    function verify_db_connection(){
        # Create database
        cd ${PROJECT_ROOT}/terraform/vault/bootstrap/mssql >/dev/null
        DB_PASSWORD=`terraform show -json | jq ".values.root_module.resources" | awk -F\" '/"password":/ {print $4}'`
        APP_NAME=`terraform show -json | jq ".values.root_module.resources" | awk -F\" '/"db_name":/ {print $4}'`
        #docker exec -it mssql /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P ${DB_PASSWORD} -Q "create database ${APP_NAME};" >/dev/null 2>&1
        docker exec -it mssql /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "Testing123" -Q "create database "${APP_NAME}";" >/dev/null 2>&1
        cd - >/dev/null

        # Create a database role with our master provisioner token
        export VAULT_TOKEN=${VR_TOKEN}

        # Output db role so they can see the specifics
        printf "\e[0;34m\nVerifying database role has been created\e[0m\n"
        vault read mssql/roles/${APP_NAME}-role

        printf "\e[0;32m\n\nApplication provisioning complete. You can now login with your ${ROLE} role, then grab your dynamic database password.\e[0m\n"

        printf "\e[0;35m\nPress any key to continue\e[0m\n"
        read -n 1 -s -r

    }

    function dynamic_cert_login(){
        # Function designed to take user input for cert/private key to then use for cert_auth login into Vault

        # Print to screen the vault command which will be used for cert login - then login
        printf "\e[0;34m\n\nTesting login with your new application cert and role - using the following command:\e[0m\n"
        printf "\n\ncurl --request POST --cert ${APP_DIR}.crt --key ${APP_DIR}/${APP_NAME}.key --data \"{\"name\": \"${APP_NAME}\"}\" ${VAULT_ADDRESS}/v1/auth/cert/login\n\n"
        curl -s --request POST --cert ${APP_DIR}/${APP_NAME}.crt --key ${APP_DIR}/${APP_NAME}.key --data "{\"name\": \"${APP_NAME}\"}" ${VAULT_ADDRESS}/v1/auth/cert/login | jq . | tee ${APP_DIR}/token.txt

        # Set the new token to a variable
        printf "\e[0;34m\nSetting the new token as our auth mechanism\e[0m\n\n"
        CERT_TOKEN=`cat ${APP_DIR}/token.txt | awk -F'"' '/client_token/ {print $4}'`
    }

    function dynamic_db_login(){
        # Function to read db creds and  login to the database
        printf "\e[0;35m\nPress any key to continue\e[0m\n"
        read -n 1 -s -r

        # Get app token as passed in demo after login. Ex cert auth or approle
        TOKEN=$1

        # Get the creds for the sql database
        printf "\e[0;34m\nGenerating dynamic database credentials with our new token.\e[0m\n"
        printf "\e[0;34m\nUsing the following command:\e[0m\n curl --header 'X-Vault-Token: ${TOKEN}' ${VAULT_ADDRESS}/v1/mssql/creds/${APP_NAME}-role\n\n"

        curl -k --silent --header "X-Vault-Token: ${TOKEN}" ${VAULT_ADDRESS}/v1/mssql/creds/${APP_NAME}-role > ${PROJECT_ROOT}/config/${APP_NAME}/db_creds

        DYN_DB_PASS=`cat ${PROJECT_ROOT}/config/${APP_NAME}/db_creds | awk -F{ '{print $3}' | awk -F, '{print $1}' | awk -F: '{print $2}' | tr -d '"'`
        DYN_DB_USER=`cat ${PROJECT_ROOT}/config/${APP_NAME}/db_creds | awk -F{ '{print $3}' | awk -F, '{print $2}' | awk -F: '{print $2}' | tr -d '}' | tr -d '"'`

        printf "\e[0;34m\nDynamic Database Username:\e[0m ${DYN_DB_USER} \n\e[0;34mDynamic Database Password:\e[0m ${DYN_DB_PASS}\n"
        # Login to the sql database and list tables
        printf "\e[0;35m\nPress any key to continue\e[0m\n"
        read -n 1 -s -r
        printf "\e[0;34m\nTesting login into the MSSQL database with the command below:\e[0m\n\n"
        printf "docker exec -it mssql /opt/mssql-tools/bin/sqlcmd -S localhost -U ${DYN_DB_USER} -P ${DYN_DB_PASS} -Q 'select name from sys.databases;'\n\n"
        docker exec -it mssql /opt/mssql-tools/bin/sqlcmd -S localhost -U $DYN_DB_USER -P $DYN_DB_PASS -Q 'select name from sys.databases;'
    }

    function orchestrator(){

        if ! ls /Library/Python/2.7/site-packages/ | grep -q "requests"
        then
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
        terraform apply -var="vault_token=${VR_TOKEN}" -var="vault_addr=${VAULT_ADDRESS}" 
        printf "\e[0;34m\nNote:\e[0m This token is created to ensure 'root' permissions are not given to the pipeline as well as for audit purposes\n\n"

        # Get the new token and set as the vault root token
        PROVISIONER_TOKEN=`terraform output -json master_provisioner_token | tr -d '"'`
        #echo "${PROVISIONER_TOKEN}"
        cd - >/dev/null 2>&1

        printf "\e[0;35m\nPress any key to continue\e[0m\n"
        read -n 1 -s -r

        # Setup App specific policies and Associated tokens
        app_policies

        # If demo option 1 was selected, create tls certs so the app can login
        if [ "${DEMO}" == "1" ];
        then
            app_certs
        fi
    }

    printf "\e[0;34m\nNext, you can choose a demo to run from the list: \e[0m\n\n"
    printf "  1. Dynamic Database Secerts with TLS Certificate Authentication\n"
    printf "  2. Dynamic Database Secerts with AppRole Authentication\n"
    printf "  3. Exit\n\n"
    read -p ":" DEMO

    case ${DEMO} in
    1)
        # Make sure both the pki engine and cert auth methods are configured
        SET_PKI=`curl --write-out '%{http_code}' --silent --header "X-Vault-Token: ${VR_TOKEN}" ${VAULT_ADDRESS}/v1/pki_int/config | grep '200' >/dev/null`
        SET_CERTS=`curl --write-out '%{http_code}' --silent --header "X-Vault-Token: ${VR_TOKEN}" ${VAULT_ADDRESS}/v1/cert/config | grep '200' >/dev/null`
        ROLE="TLS cert"

        # If the PKI Secret engine was bootstrapped - ask if we should test dynamic cert auth with dynamic secrets
        if ${SET_PKI} || ${SET_CERTS};
        then
            printf "\e[0;34m\nThis demo can walk you through the dynamic CI/CD Auth process as if you were an application, the process is:\n\n\e[0m"
            printf "    1. Generate a Provisoner Token with permission to create tokens, roles, and policies\n"
            printf "    2. Create Application specific policies\n"
            printf "    3. Generate app TLS Auth certificates via the PKI engine\n"
            printf "    4. Create TLS Auth role which references the certs from step 3\n"
            printf "    5. As the app, use your new TLS role and cert to generate your Vault access token\n"
            printf "    6. Use your new token to generate database creds based on the bootstrapped MSSQL database\n"
            printf "    7. Login to the database with your new creds\n\n"

            # Get app name - first check to see if appRole auth was bootstrapped, then ask if we should use that app name or get new now
            if curl --request LIST --write-out '%{http_code}' --silent --header "X-Vault-Token: ${VR_TOKEN}" ${VAULT_ADDRESS}/v1/auth/approle/role | grep -q 200;
            then
                printf "\e[0;34m\nLooks like you bootstrapped the AppRole auth method, would you like to use the app name as entered there(y|n)? \e[0m"
                read READ_APP_NAME

                case $READ_APP_NAME in
                y|Y|yes)
                    # Change into the appRole bootstrap dir and get the output of the fetch-token created
                    cd ${PROJECT_ROOT}/terraform/vault/bootstrap/appRole_auth 2>/dev/null 
                    APP_NAME=`terraform output -json role_name | tr -d '"'`
                    printf "\e[0;34mUsing Name:\e[0m ${APP_NAME}\n"
                    cd - >/dev/null
                ;;
                n|N|no)
                    printf "\e[0;34m\nEnter the app name you would like to use: \e[0m"
                    read APP_NAME
                ;;
                esac
            else
                printf "\e[0;34m\nEnter the app name you would like to use for this demo: \e[0m"
                read APP_NAME
            fi

            # Setup tf orchestrator a.k.a master token for provisioning
            orchestrator

            # Create demo db config
            verify_db_connection

            # Ask if they would like to test cert auth
            dynamic_cert_login

            # Call dynamic database login function
            dynamic_db_login ${CERT_TOKEN}

        else
            printf "\e[0;34m\nEither PKI Engine, TLS Auth, or MSSQL not bootstrapped, please restart this script and complete that process.\e[0m\n"
            exit 0
        fi
    ;;
    2)
        # Make sure both the pki engine and cert auth methods are configured
        SET_PKI=`curl --write-out '%{http_code}' --silent --header "X-Vault-Token: ${VR_TOKEN}" ${VAULT_ADDRESS}/v1/pki_int/config | grep '200' >/dev/null`
        SET_DB=`curl --write-out '%{http_code}' --silent --header "X-Vault-Token: ${VR_TOKEN}" ${VAULT_ADDRESS}/v1/mssql/config/${APP_NAME} | grep '200' >/dev/null`
        ROLE="AppRole"

        # If the PKI Secret engine was bootstrapped - ask if we should test dynamic cert auth with dynamic secrets
        if ${SET_PKI} || ${SET_DB};
        then
            printf "\e[0;34m\nThis demo can walk you through the dynamic CI/CD Auth process as if you were an application, the process is:\n\e[0m"
            printf "    1. Generate a Provisoner Token with permission to create tokens, roles, and policies\n"
            printf "    2. Create Application specific policies\n"
            printf "    3. As the app, use fetch token to get appRole role-id as created during the appRole bootstrap process\n"
            printf "    4. Generate a secret-ID with your fetch token and role-id\n"
            printf "    5. Login to Vault with your Role-ID and Secret-ID to generate your app auth token\n"
            printf "    6. Use your new appRole auth token to generate database creds\n"
            printf "    7. Login to the database with your new creds\n\n"

            # Get app name
            printf "\e[0;34m\nUse appRole name as entered during appRole bootstrap?(y|n) \e[0m"
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

            # Verify config as created from the bootstrap
            verify_db_connection

            # AppRole Login
            approle_login

            # Call dynamic database login function
            dynamic_db_login ${APPROLE_TOKEN}
        else
            printf "\e[0;34m\nEither PKI Engine or TLS Auth not bootstrapped, please restart this script and complete that process.\e[0m\n"
            exit 0
        fi
    ;;
    3)
        exit 0
    ;;
    esac
}

# Reset the project back to a clean slate
function reset_local(){

    # If compose already has a vault running, ask if we should stop
    if docker-compose ps | grep -q vault > /dev/null 2>&1;
    then
        printf "\e[0;34m\nStop your previous docker-compose project? \e[0m"
        read STOP_COMPOSE

        # If true, stop any docker-compose projects built with this project.
        case $STOP_COMPOSE in
        y|Y|yes)
            cd ${PROJECT_ROOT}
            docker-compose down --remove-orphans
            cd - >/dev/null 2>&1
        ;;
        n|N|no)
        ;;
        esac
    fi

    printf "\e[0;34m\nShould all previously used files be removed?\e[0m i.e Vault and Consul data, Terraform backends, and TLS Certs? "
    read RESET_BOOL

    # If true, delete all previous terraform configs, states etc.
    case $RESET_BOOL in
    y|Y|yes)
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

    ;;
    n|N|No)
    ;;
    esac

    printf "\e[0;35mReset Complete...\e[0m\n\n"
}

# Build backend files for all directories in the terraform folder
function set_backend(){
    for directory in $(find ${PROJECT_ROOT}/terraform -type d -mindepth 1 -maxdepth 3 | sed s@//@/@); do
        if [[ ${directory} == *tls* ]] | [[ ${directory} == *provisioner* ]] | [[ ${directory} == *orchestrator* ]]; then
          continue
        else
          rm -f ${directory}/backend.tf
          folder=$(echo ${directory} | awk -F "/" '{print $NF}')
          
          if [ ${VAULT_VERSION} == 1 ]
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
}

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
printf "   1. Start From The Begining\n"
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
            reset_local

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
    cluster_cert_check

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
                docker-compose -f ent-docker-compose.yml up -d 
            else
                # Start the new project in detached docker
                printf "\e[0;34m\nStarting ${PROJECT_NAME} docker-compose project detached\e[0m\n\n"
                cd ${PROJECT_ROOT}
                docker-compose -f ent-docker-compose.yml up -d
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
                    docker-compose logs vault 
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

        #if curl -s --header "X-Vault-Token: ${TOKEN}" ${VAULT_ADDRESS}/v1/sys/license | grep -i 

        printf "\n\e[0;34mDownloading License from S3\n\e[0m"
        until $( aws s3api get-object --bucket ${BUCKET_NAME} --key ${LICENSE_FILE} license.txt >/dev/null )
        do
            printf "\e[0;35m.\e[0m"
            sleep 3
        done

        LICENSE=`cat license.txt`
        cat << EOF > license.txt
{
    "text": "${LICENSE}"
}
EOF

        printf "\e[0;34mInstalling license\n\e[0m"
        sleep 2
        until $( curl --request PUT --header "X-Vault-Token: ${VR_TOKEN}" -d @license.txt ${VAULT_ADDRESS}/v1/sys/license >/dev/null 2>&1 )
        do
            printf "\e[0;35m.\e[0m"
            sleep 3
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
    ##########################################
    ### Bootstrap An Already Running Vault ###
    ##########################################

    PROJECT_NAME=$(ls ${PROJECT_ROOT}/config/cluster_certs/ | grep -v localhost | awk -F'.' '/crt/ {print $1}')
    export TF_VAR_env=${PROJECT_NAME}

    # Get project name 
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
    #################
    ### Run Demos ###
    #################

    PROJECT_NAME=$(ls ${PROJECT_ROOT}/config/cluster_certs/ | grep -v localhost | awk -F'.' '/crt/ {print $1}')
    export TF_VAR_env=${PROJECT_NAME}

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
    #####################
    ## Reset Local Env ##
    #####################

    reset_local
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
