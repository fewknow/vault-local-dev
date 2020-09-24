#!/bin/bash
export VAULT_SKIP_VERIFY=true


if [ -z "$1" ]
then
    echo "Please provide a Vault address as the first argument of this script"
    exit
else
    export VAULT_ADDR="$1"
fi


## INIT VAULT
echo "[*] Init vault..."
## TODO Put in check to determine if Vault is already initialized
## TODO Put in step to clear out _data before running
mkdir -p ../../local-vault-dev/_data
vault operator init -key-shares=3 -key-threshold=2 -address=${VAULT_ADDR} > ../../local-vault-dev/_data/keys.txt
export VAULT_TOKEN=$(grep 'Initial Root Token:' ../../local-vault-dev/_data/keys.txt | awk '{print substr($NF, 1, length($NF)-1)}')

## UNSEAL VAULT
echo "[*] Unseal vault..."
vault operator unseal -address=${VAULT_ADDR} $(grep 'Key 1:' ../../local-vault-dev/_data/keys.txt | awk '{print $NF}')
vault operator unseal -address=${VAULT_ADDR} $(grep 'Key 2:' ../../local-vault-dev/_data/keys.txt | awk '{print $NF}')
vault operator unseal -address=${VAULT_ADDR} $(grep 'Key 3:' ../../local-vault-dev/_data/keys.txt | awk '{print $NF}')
