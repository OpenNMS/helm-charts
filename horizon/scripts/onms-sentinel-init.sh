#!/bin/bash
#
# Intended to be used as part of an InitContainer
# Designed for Horizon 29 or Meridian 2021 and 2022. Newer or older versions are not supported.
#
# External environment variables used by this script:
# POSTGRES_HOST
# POSTGRES_PORT
# POSTGRES_SSL_MODE
# POSTGRES_SSL_FACTORY
# OPENNMS_SERVER
# OPENNMS_INSTANCE_ID
# OPENNMS_DBNAME
# OPENNMS_DBUSER
# OPENNMS_DBPASS
# OPENNMS_DATABASE_CONNECTION_MAXPOOL
# KAFKA_BOOTSTRAP_SERVER
# KAFKA_SASL_USERNAME
# KAFKA_SASL_PASSWORD
# KAFKA_SASL_MECHANISM
# KAFKA_SECURITY_PROTOCOL
# ELASTICSEARCH_HOSTS
# ELASTICSEARCH_FLOWS
# ELASTICSEARCH_FLOWS_CONFIG
# NUM_LISTENER_THREADS

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

umask 002

function wait_for {
  echo "Waiting for $1"
  IFS=':' read -a data <<< $1
  until printf "" 2>>/dev/null >>/dev/tcp/${data[0]}/${data[1]}; do
    sleep 5
  done
  echo "Done"
}

echo "OpenNMS Sentinel Configuration Script..."

# Defaults
OVERLAY_DIR=/opt/sentinel-etc-overlay
OPENNMS_DATABASE_CONNECTION_MAXPOOL=${OPENNMS_DATABASE_CONNECTION_MAXPOOL-50}
NUM_LISTENER_THREADS=${NUM_LISTENER_THREADS-6}
KAFKA_SASL_MECHANISM=${KAFKA_SASL_MECHANISM-PLAIN}
KAFKA_SECURITY_PROTOCOL=${KAFKA_SECURITY_PROTOCOL-SASL_PLAINTEXT}

# Configure Elasticsearch
if [[ -e /onms-sentinel-es-init.sh ]]; then
  source /onms-sentinel-es-init.sh
else
  echo "Warning: cannot find onms-sentinel-es-init.sh"
fi

# Wait for Dependencies
if [[ -v ELASTICSEARCH_HOSTNAME ]]; then
  wait_for ${ELASTICSEARCH_HOSTNAME}
fi
if [[ -v KAFKA_BOOTSTRAP_SERVER ]]; then
  wait_for ${KAFKA_BOOTSTRAP_SERVER}
fi
wait_for ${POSTGRES_HOST}:${POSTGRES_PORT}
wait_for ${OPENNMS_SERVER}:8980

echo "Configuring System Properties..."

# Configure the instance ID and Interface-to-Node cache
# Required when having multiple OpenNMS backends sharing a Kafka cluster or an Elasticsearch cluster.
CUSTOM_PROPERTIES=${OVERLAY_DIR}/custom.system.properties
if [[ ${OPENNMS_INSTANCE_ID} ]]; then
  cat <<EOF >> ${CUSTOM_PROPERTIES}
# Used for Kafka Topics
org.opennms.instance.id=${OPENNMS_INSTANCE_ID}
# Refresh Interface-to-Node cache every 2 hours
org.opennms.interface-node-cache.refresh-timer=7200000
EOF
else
  OPENNMS_INSTANCE_ID="OpenNMS"
fi

cat <<EOF > ${OVERLAY_DIR}/org.opennms.netmgt.distributed.datasource.cfg
datasource.url=jdbc:postgresql://${POSTGRES_HOST}:${POSTGRES_PORT}/${OPENNMS_DBNAME}?sslmode=${POSTGRES_SSL_MODE}&sslfactory=${POSTGRES_SSL_FACTORY}
datasource.username=${OPENNMS_DBUSER}
datasource.password=${OPENNMS_DBPASS}
datasource.databaseName=${OPENNMS_DBNAME}
connection.pool.maxSize=${OPENNMS_DATABASE_CONNECTION_MAXPOOL}
EOF

FEATURES_DIR=${OVERLAY_DIR}/featuresBoot.d
mkdir -p ${FEATURES_DIR}
cat <<EOF > ${FEATURES_DIR}/persistence.boot
sentinel-persistence
sentinel-jsonstore-postgres
sentinel-blobstore-noop
EOF

if [[ -v ELASTICSEARCH_HOSTNAME ]]; then
  echo "Configuring Flows..."

  cat <<EOF > ${FEATURES_DIR}/flows.boot
sentinel-flows
EOF

  cat <<EOF > ${OVERLAY_DIR}/org.opennms.features.telemetry.adapters-ipfix.cfg
name=IPFIX
adapters.0.name=IPFIX-Adapter
adapters.0.class-name=org.opennms.netmgt.telemetry.protocols.netflow.adapter.ipfix.IpfixAdapter
queue.threads=${NUM_LISTENER_THREADS}
EOF

  cat <<EOF > ${OVERLAY_DIR}/org.opennms.features.telemetry.adapters-netflow5.cfg
name=Netflow-5
adapters.0.name=Netflow-5-Adapter
adapters.0.class-name=org.opennms.netmgt.telemetry.protocols.netflow.adapter.netflow5.Netflow5Adapter
queue.threads=${NUM_LISTENER_THREADS}
EOF

  cat <<EOF > ${OVERLAY_DIR}/org.opennms.features.telemetry.adapters-netflow9.cfg
name=Netflow-9
adapters.0.name=Netflow-9-Adapter
adapters.0.class-name=org.opennms.netmgt.telemetry.protocols.netflow.adapter.netflow9.Netflow9Adapter
queue.threads=${NUM_LISTENER_THREADS}
EOF
fi

if [[ -v KAFKA_BOOTSTRAP_SERVER ]]; then
  echo "Configuring Kafka for Flows..."

  FILE_PREFIX="${OVERLAY_DIR}/org.opennms.core.ipc.sink.kafka"
  echo "sentinel-kafka" > ${FEATURES_DIR}/kafka.boot

  cat <<EOF > ${FILE_PREFIX}.cfg
# Producers
bootstrap.servers=${KAFKA_BOOTSTRAP_SERVER}
acks=1
EOF

  cat <<EOF > ${FILE_PREFIX}.consumer.cfg
# Consumers
group.id=${OPENNMS_INSTANCE_ID}_Sentinel
bootstrap.servers=${KAFKA_BOOTSTRAP_SERVER}
max.partition.fetch.bytes=5000000
EOF

  for f in ${FILE_PREFIX}.cfg ${FILE_PREFIX}.consumer.cfg; do
    cat <<EOF >> $f
# Security
security.protocol=${KAFKA_SECURITY_PROTOCOL}
sasl.mechanism=${KAFKA_SASL_MECHANISM}
EOF
    if [[ -v KAFKA_SASL_USERNAME ]] &&  [[ -v KAFKA_SASL_PASSWORD ]]; then
      if [[ -v KAFKA_SASL_MECHANISM ]] && [[ "${KAFKA_SASL_MECHANISM}" == *"SCRAM"* ]]; then
        JAAS_CLASS="org.apache.kafka.common.security.scram.ScramLoginModule"
      else
        JAAS_CLASS="org.apache.kafka.common.security.plain.PlainLoginModule"
      fi
      cat <<EOF >> $f
sasl.jaas.config=${JAAS_CLASS} required username="${KAFKA_SASL_USERNAME}" password="${KAFKA_SASL_PASSWORD}";
EOF
    fi
  done
fi
