#!/bin/bash
#
# Intended to be used as part of an InitContainer expecting to run to configure Elastic settings
#
# External environment variables used by this script:

echo "Elastic Config Initialization Script..."

# Configure Elasticsearch to allow Flow data
if [[ ${ELASTICSEARCH_FLOWS} == "true" ]]; then
  echo "Configuring Elasticsearch for Flows..."
  PREFIX=$(echo ${OPENNMS_INSTANCE_ID} | tr '[:upper:]' '[:lower:]')-
  cat <<EOF > ${CONFIG_DIR_OVERLAY}/org.opennms.features.flows.persistence.elastic.cfg
elasticUrl=${ELASTICSEARCH_HOSTS}
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
  if [[ -v ELASTICSEARCH_USER ]]; then
  echo globalElasticUser=${ELASTICSEARCH_USER} >> ${CONFIG_DIR_OVERLAY}/org.opennms.features.flows.persistence.elastic.cfg
  echo globalElasticPassword=${ELASTICSEARCH_PASSWORD} >> ${CONFIG_DIR_OVERLAY}/org.opennms.features.flows.persistence.elastic.cfg
 fi
fi

# Configure Elasticsearch to allow Alarm History
if [[ ${ELASTICSEARCH_ALARMS} == "true" ]]; then
  echo "Configuring Elasticsearch for Alarms..."
  PREFIX=$(echo ${OPENNMS_INSTANCE_ID} | tr '[:upper:]' '[:lower:]')-
  cat <<EOF > ${CONFIG_DIR_OVERLAY}/org.opennms.features.alarms.history.elastic.cfg
elasticUrl=${ELASTICSEARCH_HOSTS}
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
  if [[ -v ELASTICSEARCH_USER ]]; then
  echo globalElasticUser=${ELASTICSEARCH_USER} >> ${CONFIG_DIR_OVERLAY}/org.opennms.features.alarms.history.elastic.cfg
  echo globalElasticPassword=${ELASTICSEARCH_PASSWORD} >> ${CONFIG_DIR_OVERLAY}/org.opennms.features.alarms.history.elastic.cfg
 fi
#cat <<EOF > ${CONFIG_DIR_OVERLAY}/featuresBoot.d/alarm-history.boot
#opennms-alarm-history-elastic
#EOF
fi
