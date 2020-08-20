#!/bin/bash

LOCAL=$1
ROOT=`pwd`

function reset()
{
  PATH=$1
  echo "Setting up terraform backend"
  for directory in $PATH/*; do
    echo "PATH : $directory"
    if [[ -d "${directory}" ]]; then
       if [[ ${directory} == *tls* ]] || [[ ${directory} == *provisioner* ]] || [[ ${directory} == *orchestrator* ]] || [[ ${directory} == *bootstrap_config* ]]; then
         echo "Skipping directoy : $directory becuase it doesn't need state"
         continue
       else
         echo "Remove backend.tf first"
         rm -rf backend.tf
         folder=$(echo "${directory}" | awk -F "/" '{print $NF}')
         echo "FOLDER SHOULD BE : ${folder}"
         echo "setting "${directory}"/backend.tf"
         if [ "${LOCAL}" == "true" ]; then
           echo "Setiting Consul Backend local"
           echo "terraform {
                  backend \"consul\" {
                    path = \"vault/${folder}\"
                  }
                }" > ${directory}/backend.tf
         elif [ "$LOCAL" != "true" ]; then
           echo "Setiting Consul Backend artifactory"
           echo "terraform {
                  backend \"artifactory\" {
                    subpath = \"vault/${folder}\"
                  }
                }" > ${directory}/backend.tf
         fi
      fi

       reset $directory


    elif [[ -f "${directory}" ]]; then
      echo "Nothing to do for ${directory}"
    fi

  done
}

reset $ROOT
