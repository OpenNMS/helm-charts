#!/bin/bash


checkRC(){
    return_code=$?
    if [ $return_code -ne 0 ]; then
        printf "\033[31m%s\n\033[0m" "An error occured as the return code is not 0!"
        exit $return_code
    fi 
}

if ! command -v crc   >/dev/null 2>&1; then
 echo "Unable to find CRC command! Exiting.."
 exit 1
fi

if ! command -v oc   >/dev/null 2>&1; then
  eval $(crc oc-env)                                                                                                    
fi

export WhoAmI=$(oc whoami)

if [ "$WhoAmI" != "kubeadmin" ];then 
 echo "You need to be logged in as kubeadmin! Exiting..."
fi

oc exec postgres-0 -- dropdb opennms_opennms -U postgres
checkRC