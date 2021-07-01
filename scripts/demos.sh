#!/bin/bash

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