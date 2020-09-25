#!/bin/bash

# Prints out root token to console so Ansible can detect and register the value

KEYS_FILE='../_data/keys.txt'
if [ ! -f "$KEYS_FILE" ]; then
    exit 0
fi

awk '/Root Token:/{print $4}' $KEYS_FILE
