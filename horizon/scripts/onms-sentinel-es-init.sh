#!/bin/bash
#
# Intended to be used as part of an InitContainer expecting to run to configure Elastic settings
#
# External environment variables used by this script:

# OVERLAY_DIR
# ELASTICSEARCH_FLOWS
# ELASTICSEARCH_FLOWS_CONFIG
# ELASTICSEARCH_HOSTS
# OPENNMS_INSTANCE_ID

echo "Elastic Config Initialization Script..."

if [[ -v ELASTICSEARCH_HOSTS ]]; then
  echo "Configuring Elasticsearch credentials"
  IFS=';' read -a ES_HOSTS <<< ${ELASTICSEARCH_HOSTS}
  ESHOST=""
  ELASTICSEARCH_HOSTNAME=""
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
    if [[ -z "${ELASTICSEARCH_HOSTNAME}" ]]; then
      ELASTICSEARCH_HOSTNAME=${host}
    fi
    ESHOST+="${ES_URL},"
  done
 ESHOST=${ESHOST%?}
 ESCREDS+="</elastic-credentials>"
  echo -e ${ESCREDS} > ${OVERLAY_DIR}/elastic-credentials.xml
fi


# Configure Elasticsearch to allow Flow data
if [[ ${ELASTICSEARCH_FLOWS} == "true" ]]; then
  echo "Configuring Elasticsearch for Flows..."
  PREFIX=$(echo ${OPENNMS_INSTANCE_ID} | tr '[:upper:]' '[:lower:]')-
  cat <<EOF > ${OVERLAY_DIR}/org.opennms.features.flows.persistence.elastic.cfg
elasticUrl=${ESHOST}
indexPrefix=${PREFIX}
EOF
  if [[ -v ELASTICSEARCH_FLOWS_CONFIG ]]; then
    IFS=';' read -a ES_CONFIG <<< ${ELASTICSEARCH_FLOWS_CONFIG}
    ESCFG=""
    for LINE in ${ES_CONFIG[@]}; do
      ESCFG+="${LINE}\n"
    done
    echo -e ${ESCFG} >> ${OVERLAY_DIR}/org.opennms.features.flows.persistence.elastic.cfg
  fi
fi
