#!/bin/bash

export max_connections=50000


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

echo "Getting max_connections"
oc exec postgres-0 -- psql -c "SHOW max_connections" -U postgres
checkRC

echo "Setting current max_connections"
oc exec postgres-0 -- psql -c "ALTER SYSTEM SET max_connections = ${max_connections};" -U postgres
checkRC

echo "Restart postgres"
oc scale statefulset postgres --replicas=0
checkRC
oc scale statefulset postgres --replicas=1
checkRC
sleep 45

echo "Getting max_connections"
oc exec postgres-0 -- psql -c "SHOW max_connections" -U postgres
checkRC