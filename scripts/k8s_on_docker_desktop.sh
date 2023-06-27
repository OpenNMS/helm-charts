#!/bin/bash

#
# This script helps with bringing up the Helm Charts in a development environment
#

promptAndConfirm(){
    read -r -p "$1 " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        [nN][oO]|[nN])
            printf "\033[31m%s\n\033[0m" "Exiting"
            exit
            ;;
        *)
          printf "\033[31m%s\n\033[0m" "invalid input!"
          exit
    esac
}

checkRC(){
    return_code=$?
    if [ $return_code -ne 0 ]; then
        printf "\033[31m%s\n\033[0m" "An error occured as the return code is not 0!"
        exit $return_code
    fi 
}

export root_path=""
if [ ! -d "examples" ]; then
 if [ -d "../examples" ]; then
  root_path="../"
 fi
fi

export additional_helm_charts="-f ${root_path}examples/minimal-resources.yaml -f ${root_path}examples/kill-it-with-fire.yaml "


export log_file="${root_path}log.txt"

export our_domain=""
export our_namespace=""
export domain_defined=false

if [ -z "$our_domain" ]; then
 read -p "Domain: " our_domain
fi

if [ -z "$our_namespace" ]; then
 read -p "NameSpace: " our_namespace
fi

clear

export our_kafka_domain=".$our_domain"
echo "----" | tee -a $log_file
echo "Date: $(date)" | tee -a $log_file
echo "Domain: $our_domain" | tee -a $log_file
echo "Kafka Domain: $our_kafka_domain" | tee -a $log_file
echo "Namespace: $our_namespace" | tee -a $log_file
echo $(grep "appVersion: \?" ${root_path}horizon/Chart.yaml)
echo $(grep "opennmsVersion: \?" ${root_path}horizon/values.yaml)
echo ""

# Maybe switch this check to \(onms-core\|*\).$our_namespace.$our_domain
if grep -q "onms-core.$our_namespace.$our_domain" /etc/hosts; then
 printf "\033[32m%s\033[0m\n"  "Found an entry for onms-core.$our_namespace.$our_domain in /etc/hosts"
 domain_defined=true
 echo ""
else
 printf "\033[36m%s\033[0m:\033[0m\033[33m %s\n\033[0m" "Recommendation" "We couldn't find an entry for onms-core.$our_namespace.$our_domain in /etc/hosts. It is recommended to add the following line to /etc/hosts, before proceeding."
 printf "\t%s\n" "127.0.0.1 onms-core.$our_namespace.$our_domain"
 echo ""
fi

promptAndConfirm "Does the information above look correct? [y/n]"
echo ""
printf "\033[36m%s\033[0m\033[0m\033[33m %s\n\033[0m" "You can find a copy of the logs in" "$log_file"
echo ""
printf "\033[36m%s\033[0m:\033[0m\033[33m %s\n\033[0m" "Step 1" "Modifying dependencies/kafka.yaml"
sed -rie 's/(host: kafka(-0)?).*/\1'$our_kafka_domain'/g' "${root_path}dependencies/kafka.yaml"
echo ""

# Ingress is not really active/installed, lets install it
printf "\033[36m%s\033[0m:\033[0m\033[33m %s\n\033[0m" "Step 2" "Check/Install Ingress"
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace >> $log_file 2>&1
checkRC

sleep 10

echo ""

# Start the dependencies
printf "\033[36m%s\033[0m:\033[0m\033[33m %s\n\033[0m" "Step 3" "Starting Dependencies"
${root_path}scripts/start-dependencies.sh  >> $log_file 2>&1
checkRC
echo ""

printf "\033[36m%s\033[0m:\033[0m\033[33m %s\n\033[0m" "Step 4" "Installing OpenNMS"
helm upgrade --install $additional_helm_charts --set domain=$our_domain $our_namespace ${root_path}horizon >> $log_file 2>&1
checkRC
echo ""

printf "\033[36m%s\033[0m:\033[0m\033[33m %s\n\033[0m" "Step 5" "Waiting for OpenNMS Stateful container to come up"

replicate_status=$(kubectl get statefulset.apps/onms-core -n $our_namespace -o=jsonpath='{.status.availableReplicas}')

while [ "$replicate_status" -ne 1 ]
do 
replicate_status=$(kubectl get statefulset.apps/onms-core -n $our_namespace -o=jsonpath='{.status.availableReplicas}')
done
echo ""

if $domain_defined; then
 printf "\033[36m%s\033[0m:\033[0m\033[33m %s\n\033[0m" "Step 6" "Waiting for OpenNMS instance url to be accessible"
 curl -k -s --retry 50 -f --retry-all-errors --retry-delay 5 -o /dev/null "https://onms-core.$our_namespace.$our_domain/opennms/login.jsp"
else 
 printf "\033[36m%s\033[0m:\033[0m\033[33m %s\n\033[0m" "Reminder" "It is recommended to add the following line to /etc/hosts."
 printf "\t%s\n" "127.0.0.1 onms-core.$our_namespace.$our_domain"
fi
echo ""

printf "\033[36m%s\033[0m:\033[0m\033[33m %s\n\033[0m" "Step 7" "Undo changes to dependencies/kafka.yaml and remove dependencies/kafka.yamle"
sed -rie 's/(host: kafka(-0)?).*/\1.k8s.agalue.net/g' "${root_path}dependencies/kafka.yaml"
rm "${root_path}dependencies/kafka.yamle"
echo ""

tail -8 $log_file
