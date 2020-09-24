#!/bin/bash
KEYS_FILE='../../local-vault-dev/_data/keys.txt'
if [ ! -f "$KEYS_FILE" ]; then
    exit 0
fi

export ROOT_TOKEN_FOR_ANSIBLE=$(awk '/Root Token:/{print $4}' $KEYS_FILE)
#bash ../../local-vault-dev/token_replacer.sh