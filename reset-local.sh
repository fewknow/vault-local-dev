#!/bin/bash
rm -rf ./_data
rm -rf ../vault/vault
cd ..
ROOT=`pwd`


function reset()
{
  echo "Clearing apps, consul, orchestrator"
  for directory in $1/*; do
    echo "PATH : $directory"
    if [[ -d "${directory}" ]]; then
       echo "deleting ${directory}/.terraform"
       rm -rf ${directory}/.terraform
       echo "deleting terraform.tfstate.d"
       rm -rf ${directory}/terraform.tfstate.d
       echo "deleting terraform.tfstate"
       rm -rf ${directory}/terraform.tfstate
       echo "deleting terraform.tfstate.backup"
       rm -rf ${directory}/terraform.tfstate.backup
       echo "delete backends"
       rm -rf ${directory}/backend.tf
       reset $directory


    elif [[ -f "${directory}" ]]; then
      echo "Nothing to do for ${directory}"
    fi

  done
}

reset $ROOT/terraform 
