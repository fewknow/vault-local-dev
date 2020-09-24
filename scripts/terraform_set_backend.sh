#!/bin/bash

LOCAL="$1"
ROOT=`pwd`

function reset()
{
  echo "Setting up terraform backend"
  for directory in $1/*; do
    #echo "PATH : $directory"
    if [[ -d "${directory}" ]]; then
       if [[ ${directory} == *tls* ]] || [[ ${directory} == *provisioner* ]] || [[ ${directory} == *orchestrator* ]] || [[ ${directory} == *bootstrap_config* ]]; then
        #  echo "Skipping directoy : $directory becuase it doesn't need state"
         continue
       else
         echo "Removing backend.tf first"
         rm -rf backend.tf
         folder=$(echo ${directory} | awk -F "/" '{print $NF}')
         echo "FOLDER SHOULD BE : ${folder}"
         echo "setting ${directory}/backend.tf"
         if [ "${LOCAL}" == "true" ]; then
           echo "Setting Consul Backend local"
           echo "terraform {
                  backend \"consul\" {
                    path = \"vault/${folder}\"
                  }
                }" > ${directory}/backend.tf
         elif [ "$LOCAL" != "true" ]; then
           echo "Setting Consul Backend artifactory"
           echo "terraform {
                  backend \"artifactory\" {
                    subpath = \"vault/tfvars\"
                  }
                }" > ${directory}/backend.tf
         fi
       fi

       reset $directory


    # elif [[ -f "${directory}" ]]; then
    #   echo "Nothing to do for ${directory}"
    fi

  done
}

reset $ROOT