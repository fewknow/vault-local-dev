#!/bin/bash -x

set -e


#########################################################
###############   Local DEV #############################
#########################################################
IP=`ifconfig | grep "inet " | grep 192| awk '{print $2}'`


################################################################
# THESE ARE ALL TERRAFORM INPUT VALUES TO CLOUT ININT TEMPLATE #
################################################################
ASG_NAME="rke-demo-worker20201030185305668000000009"
instance_id="fewknow-1"
cluster_name="fewknow"
region="us-west-2"
bucket_name="ian-bucket-dev"
license_file="license.txt"
kms_key_id="f094181b-9097-4ca1-9935-c89f8a196fea"
FILE_FINAL=vault.hcl
FILE_TMP=/tmp/$FILE_FINAL.tmp
leader="192.168.4.99"
NUMBER_OF_SHARES=5
THRESHOLD=3
LEADER=true
#-----------
ENT_VAULT_VERSION="1.6.0"
ENABLE_VAULT_UI=true
VAULT_RELEASES_URL="https://releases.hashicorp.com/vault"
VAULT_CONFIG_DIR="/etc/vault.d"
################################################################
# THESE ARE ALL TERRAFORM INPUT VALUES TO CLOUT ININT TEMPLATE #
################################################################

#########################################################
###############  Local DEV ##############################
#########################################################

##################################################
################# AWS ONLY ######################
#################################################
echo "Starting deployment from AMI: ${ami}"
#export availability_zone="$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)"
#export instance_id="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
#export local_ipv4="$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
export VAULT_ADDR=http://127.0.0.1:8200

################################################
################################################
################################################

# Create user/group
if ! grep "vault" /etc/passwd
then
    printf "\e[0;34m\nCreating Vault User and Group\n\e[0m"
    sudo useradd vault
    sudo usermod -aG vault vault
fi

echo "Creating /etc/vault.d and /opt/vault/data"

sudo mkdir -p /etc/vault.d/
sudo touch /etc/vault.d/vault.hcl

sudo mkdir -p /opt/vault/
sudo mkdir -p /opt/vault/data


# First install the deps
apt update

echo "installing needed tools"
apt -y install curl jq unzip vim awscli


echo "Configuring system time"
timedatectl set-timezone UTC

# generate vault config
cat << EOF > /etc/vault.d/vault.hcl
disable_performance_standby = true
ui = true
storage "raft" {
  path    = "/opt/vault/data"
  node_id = "vault_${instance_id}"
  auto_join_scheme = "http"
  retry_join {
    auto_join = "provider=aws region=${region} tag_key=vault tag_value=${cluster_name}"
  }
}
cluster_addr = "https://$local_ipv4:8201"
api_addr = "https://0.0.0.0:8200"
listener "tcp" {
 address     = "0.0.0.0:8200"
 tls_disable = 0
 tls_cert_file = "/etc/certs/vault.crt"
 tls_key_file = "/etc/certs/vault.key"
}
seal "awskms" {
  region     = "${region}"
  kms_key_id = "${kms_key_id}"
}
EOF

echo "Setting owner and permissionf for /etc/vault.d and /opt/vault"

chown -R vault:vault /etc/vault.d/*
chmod -R 700 /etc/vault.d/*
chown -R vault.vault /etc/certs
chown -R vault:vault /opt/vault/*
chmod -R 700 /opt/vault/*



# Download the enterprise vault binary
printf "\e[0;34m\nDownloading\e[0m Vault ${ENT_VAULT_VERSION}+ent\n\n"
curl --output vault_${ENT_VAULT_VERSION}.zip ${VAULT_RELEASES_URL}/${ENT_VAULT_VERSION}+ent/vault_${ENT_VAULT_VERSION}+ent_linux_amd64.zip

# Extract, update perms and move to the correct folder for installed binaries
printf "\e[0;34m\nExtracting\n\e[0m"
unzip vault_${ENT_VAULT_VERSION}.zip
sudo chown root:root vault
sudo mv vault /usr/local/bin

# Create systemd file
printf "\e[0;34mCreating Systemd Service definition\e[0m\n"

cat << EOF > /tmp/vault.service
[Unit]
Description="HashiCorp Enterprise Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/vault.hcl
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=60
StartLimitIntervalSec=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity
StandardOutput=file:/var/log/vault_init.log
StandardError=file:/var/log/vault_error.log

[Install]
WantedBy=multi-user.target
EOF

# # Create config dir, mv in our generated conf and update perms
# printf "\e[0;34mCreating Vault Directories and Config Files\n\e[0m"
# sudo mkdir -p ${VAULT_CONFIG_DIR}
# sudo mv -f $FILE_TMP ${VAULT_CONFIG_DIR}/$FILE_FINAL
# sudo chown -R vault:vault ${VAULT_CONFIG_DIR}
# sudo chmod -R 700 ${VAULT_CONFIG_DIR}
# sudo chmod 640 ${VAULT_CONFIG_DIR}/vault.hcl
# sudo mkdir -p /opt/raft
# sudo chown vault.vault /opt/raft
# sudo chmod 700 /opt/raft




# Configure shell autocomplete
if ! grep "complete -C /usr/local/bin/vault vault" ~/.bashrc
then
    printf "\e[0;34mEnabling vault cli auto-complete\n\e[0m"
    vault -autocomplete-install
    bash -c 'complete -C /usr/local/bin/vault vault'
fi

echo "copy over aws creds so I can start vault"
sudo mkdir /home/vault
sudo mkdir /home/vault/.aws
sudo cp -R /root/.aws/* /home/vault/.aws/
sudo chown -R vault:vault /home/vault

echo "proceeding to start Vault service"
printf "\e[0;34mEnabling and starting vault service\n\e[0m"
sudo su - <<EOF
sudo mv /tmp/vault.service /etc/systemd/system/vault.service
sudo systemctl enable vault
sudo systemctl start vault
sudo systemctl status vault
EOF


sleep 5

echo "Check health"
# echo "HEALTH=`curl --write-out '%{http_code}' --silent http://127.0.0.1:8200/v1/sys/health | tail -n1`"
HEALTH=`curl -k --write-out '%{http_code}' --silent https://127.0.0.1:8200/v1/sys/health | tail -n1`
echo "Health is : ${HEALTH}"
until [ ${HEALTH} -eq "200" ]; do
 echo "Not Healthy, sleeping 5"
   sleep 5
   if [ "${HEALTH}" -eq "503" -o "${HEALTH}" -eq "501" -o "${HEALTH}" -eq "400" ]; then
     echo "Health is : ${HEALTH}, need to initialize vault"
     echo "Vault is sealed"
     echo "Now init vault with operator"
     echo "vault operator init -recovery-shares=${NUMBER_OF_SHARES} -recovery-threshold=${NUMBER_OF_SHARES}"
     export VAULT_SKIP_VERIFY=true
     
     vault operator init -recovery-shares=${NUMBER_OF_SHARES} -recovery-threshold=${THRESHOLD} -address="https://127.0.0.1:8200" > init.txt

     for i in $(cat init.txt | awk "/Recovery Key/ {print \$1, \$2, \$3 , \$4}"); do
       UNSEAL_KEY=${i}
       echo "$UNSEAL_KEY" >> keys.txt
     done

     TOKEN=`cat init.txt | grep Initial | cut -d':' -f2 | tr -d '[:space:]'`
     echo $TOKEN
     echo "TOKEN : $TOKEN" >> keys.txt

     aws s3 cp keys.txt "s3://${bucket_name}/"
     echo "sleep 2"
     sleep 2
  fi
  echo "Check health again,  last known health was : ${HEALTH}"
  echo "HEALTH=`curl --write-out '%{http_code}' --silent https://127.0.0.1:8200/v1/sys/health | tail -n1`"
  HEALTH=`curl -k --write-out '%{http_code}' --silent https://127.0.0.1:8200/v1/sys/health | tail -n1`

done

echo "Healther is : ${HEALTH}, we can procces with license"

# Get license
printf "\e[0;34mDownloading License from S3\n\e[0m"
aws s3api get-object --bucket ${bucket_name} --key ${license_file} license.txt >/dev/null
LICENSE=`cat license.txt`
cat << EOF > license.txt
{
    "text": "${LICENSE}"
}
EOF

printf "\e[0;34m\nAdding license\n\e[0m"
curl -k --request PUT --header "X-Vault-Token: ${TOKEN}" -d @license.txt https://127.0.0.1:8200/v1/sys/license

sleep 5

printf "\e[0;34mCheck license is now non-temporary\n\e[0m"
curl -s -k --header "X-Vault-Token: ${TOKEN}" https://127.0.0.1:8200/v1/sys/license | jq '.data'
