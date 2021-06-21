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

cluster_cert_check