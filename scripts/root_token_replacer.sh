# #!/bin/bash
# ANSIBLE_TOKEN_FILE='./roles/bootstrap-environment/vars/main.yml'
# if [ ! -f "$ANSIBLE_TOKEN_FILE" ]; then
#     exit 0
# fi

# gsed "s/token:.*/token: $ROOT_TOKEN_FOR_ANSIBLE/g" -i $ANSIBLE_TOKEN_FILE

# TODO check if this is required exclusively for the bootstrap playbook