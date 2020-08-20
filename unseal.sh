#!/bin/bash

KEYS_FILE='_data/keys.txt'
export VAULT_SKIP_VERIFY=true
export VAULT_ADDR=https://localhost:8200

# INIT VAULT
echo "[*] Init vault..."
vault operator init -key-shares=3 -key-threshold=2 -address=${VAULT_ADDR} > $KEYS_FILE
export VAULT_TOKEN=$(awk '/Root Token:/{print substr($4, 1, length($4)-1)}')

# UNSEAL VAULT
echo "[*] Unseal vault..."

for i in {1..3}; do
    UNSEAL_KEY=$(awk "/Key $i:/ {print \$4}" $KEYS_FILE)
    vault operator unseal -address=${VAULT_ADDR} "$UNSEAL_KEY"
done
