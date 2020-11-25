





#!/bin/bash -x



set -e


#########################################################
###############   Local DEV #############################
#########################################################

export VAULT_ADDR=http://127.0.0.1:8200

IP=`ifconfig | grep "inet " | grep 192| awk '{print $2}'`

################################################################
# THESE ARE ALL TERRAFORM INPUT VALUES TO CLOUT ININT TEMPLATE #
################################################################
ASG_NAME="rke-demo-worker20201030185305668000000009"
node_id="fewknow-1"
cluster_name="fewknow"
region="us-west-2"
bucket_name="ian-bucket-dev"
license_file="license.txt"
kms_key_id="f094181b-9097-4ca1-9935-c89f8a196fea"
FILE_FINAL=vault.conf
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

sudo chown ${USER:=$(/usr/bin/id -run)}:$USER $FILE_TMP

sudo sed -i -- "s|{{ node_id }}|${node_id}|g" $FILE_TMP
sudo sed -i -- "s|{{ cluster_name }}|${cluster_name}|g" $FILE_TMP
sudo sed -i -- "s|{{ region }}|${region}|g" $FILE_TMP
sudo sed -i -- "s|{{ kms_key_id }}|${kms_key_id}|g" $FILE_TMP
sudo sed -i -- "s|{{ ip }}|${IP}|g" $FILE_TMP
sudo sed -i -- "s|{{ leader }}|${leader}|g" $FILE_TMP
echo "ui = ${ENABLE_VAULT_UI}" >> $FILE_TMP
echo "api_addr = \"http://$IP:8200\"" >> $FILE_TMP


## Install Ent Vault ##
#------------

# First install the deps
sudo apt -y install curl jq unzip vim awscli

# Download the enterprise vault binary
printf "\e[0;34m\nDownloading\e[0m Vault ${ENT_VAULT_VERSION}+ent\n\n"
curl --output vault_${ENT_VAULT_VERSION}.zip ${VAULT_RELEASES_URL}/${ENT_VAULT_VERSION}+ent/vault_${ENT_VAULT_VERSION}+ent_linux_amd64.zip

# Extract, update perms and move to the correct folder for installed binaries
printf "\e[0;34m\nExtracting\n\e[0m"
unzip vault_${ENT_VAULT_VERSION}.zip
sudo chown root:root vault
sudo mv vault /usr/local/bin

# Create user/group
if ! grep "vault" /etc/passwd
then
    printf "\e[0;34m\nCreating Vault User and Group\n\e[0m"
    sudo useradd vault
fi
sudo mkdir -p /home/vault
sudo cp -R /root/.aws /home/vault/
sudo chown -R vault:vault /home/vault

# Create config dir, mv in our generated conf and update perms
printf "\e[0;34mCreating Vault Directories and Config Files\n\e[0m"
sudo mkdir -p ${VAULT_CONFIG_DIR}
sudo mv -f $FILE_TMP ${VAULT_CONFIG_DIR}/$FILE_FINAL
sudo chown -R vault:vault ${VAULT_CONFIG_DIR}
sudo chmod -R 700 ${VAULT_CONFIG_DIR}
sudo chmod 640 ${VAULT_CONFIG_DIR}/vault.conf
sudo mkdir -p /opt/raft
sudo chown vault.vault /opt/raft
sudo chmod 700 /opt/raft


# Create systemd file
printf "\e[0;34mCreating Systemd Service definition\e[0m\n"

cat << EOF > /tmp/vault.service
[Unit]
Description="HashiCorp Enterprise Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/vault.conf
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
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault.conf
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

[Install]
WantedBy=multi-user.target
EOF

# Configure shell autocomplete
if ! grep "complete -C /usr/local/bin/vault vault" ~/.bashrc
then
    printf "\e[0;34mEnabling vault cli auto-complete\n\e[0m"
    vault -autocomplete-install
    bash -c 'complete -C /usr/local/bin/vault vault'
fi

# Update cap.lock
sudo setcap cap_ipc_lock=+ep /usr/local/bin/vault

printf "\e[0;34mEnabling and starting vault service\n\e[0m"
sudo su - <<EOF
sudo mv /tmp/vault.service /etc/systemd/system/vault.service
sudo systemctl enable vault
sudo systemctl start vault
sudo systemctl status vault
EOF

sleep 3

echo "Check healther"
echo "HEALTH=`curl --write-out '%{http_code}' --silent http://127.0.0.1:8200/v1/sys/healthe | tail -n1`"
HEALTH=`curl --write-out '%{http_code}' --silent http://127.0.0.1:8200/v1/sys/healthe | tail -n1`
echo "Health is : ${HEALTH}"
until [ ${HEALTH} == "200" ]; do
 echo "Not Healthy, sleeping 5"
 sleep 5

   if [ ${HEALTH} == "503" ] || [ ${HEALTH} == "501" ] ; do
    echo "Health is : ${HEALTH}, need to initialize vault"
    if [ -z ${SEALED} ]; do
       echo "Vault is sealed"
       echo "Now init vault with operator"
       echo "vault operator init -recovery-shares=${NUMBER_OF_SHARES} -recovery-threshold=${NUMBER_OF_SHARES}"

       vault operator init -recovery-shares=${NUMBER_OF_SHARES} -recovery-threshold=${THRESHOLD} > init.txt

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
  else
    echo "SOMETHING IS WRONG!!!!!  Current health : ${HEALTH}"
  fi

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

# PuT license
printf "\e[0;34m\nWaiting for Vault to complete initialization\e[0m"
until curl -s --header "X-Vault-Token: ${ROOT_TOKEN}" http://127.0.0.1:8200/v1/sys/license | grep -si "temporary" >/dev/null
do
    printf "\e[0;35m.\e[0m"
    sleep 3
done

printf "\e[0;34m\nAdding license\n\e[0m"
curl --request PUT --header "X-Vault-Token: ${ROOT_TOKEN}" -d @license.txt http://127.0.0.1:8200/v1/sys/license
rm -f license.txt

printf "\e[0;34mCheck license is now non-temporary\n\e[0m"
curl -s --header "X-Vault-Token: ${ROOT_TOKEN}" http://127.0.0.1:8200/v1/sys/license | jq '.data'
