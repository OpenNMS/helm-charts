#!/bin/bash
#
# Intended to be used as part of an InitContainer expecting to run to configure Elastic settings
#
# External environment variables used by this script:

echo "Elastic Config Initialization Script..."

if [[ -v ELASTICSEARCH_HOSTS ]]; then
  echo "Configuring Elasticsearch credentials"
  IFS=';' read -a ES_HOSTS <<< ${ELASTICSEARCH_HOSTS}
  ESHOST=""
  ESCREDS="<elastic-credentials>\n"
  for url in ${ES_HOSTS[@]}; do
    without_protocol="${url#*://}"
    protocol="${url%%://*}"
    if [[ ${without_protocol} == *"@"* ]]; then
      username_password="${without_protocol%%@*}"
      IFS=':' read -r username password <<< "$username_password"
      host="${without_protocol#*@}"
      ES_URL="${protocol}://${host}"
      ESCREDS+="   <credentials url=\"${ES_URL}\" username=\"${username}\" password=\"${password}\"/> \n"
    else
      host=${without_protocol}
      ES_URL="${protocol}://${host}"
    fi
    ESHOST+="${ES_URL},"
  done
 ESHOST=${ESHOST%?}
 ESCREDS+="</elastic-credentials>"
  echo -e ${ESCREDS} > ${CONFIG_DIR_OVERLAY}/elastic-credentials.xml
fi


# Configure Elasticsearch to allow Flow data
if [[ ${ELASTICSEARCH_FLOWS} == "true" ]]; then
  echo "Configuring Elasticsearch for Flows..."
  PREFIX=$(echo ${OPENNMS_INSTANCE_ID} | tr '[:upper:]' '[:lower:]')-
  cat <<EOF > ${CONFIG_DIR_OVERLAY}/org.opennms.features.flows.persistence.elastic.cfg
elasticUrl=${ESHOST}
indexPrefix=${PREFIX}
EOF
  if [[ -v ELASTICSEARCH_FLOWS_CONFIG ]]; then
    IFS=';' read -a ES_CONFIG <<< ${ELASTICSEARCH_FLOWS_CONFIG}
    ESCFG=""
    for LINE in ${ES_CONFIG[@]}; do
      ESCFG+="${LINE}\n"
    done
    echo -e ${ESCFG} >> ${CONFIG_DIR_OVERLAY}/org.opennms.features.flows.persistence.elastic.cfg
  fi
fi

# Configure Elasticsearch to allow Alarm History
if [[ ${ELASTICSEARCH_ALARMS} == "true" ]]; then
  echo "Configuring Elasticsearch for Alarms..."
  PREFIX=$(echo ${OPENNMS_INSTANCE_ID} | tr '[:upper:]' '[:lower:]')-
  cat <<EOF > ${CONFIG_DIR_OVERLAY}/org.opennms.features.alarms.history.elastic.cfg
elasticUrl=${ESHOST}
indexPrefix=${PREFIX}
EOF
  if [[ -v ELASTICSEARCH_ALARMS_CONFIG ]]; then
    IFS=';' read -a ES_CONFIG <<< ${ELASTICSEARCH_ALARMS_CONFIG}
    ESCFG=""
    for LINE in ${ES_CONFIG[@]}; do
      ESCFG+="${LINE}\n"
    done
    echo -e ${ESCFG} >> ${CONFIG_DIR_OVERLAY}/org.opennms.features.alarms.history.elastic.cfg
  fi
#cat <<EOF > ${CONFIG_DIR_OVERLAY}/featuresBoot.d/alarm-history.boot
#opennms-alarm-history-elastic
#EOF
fi
