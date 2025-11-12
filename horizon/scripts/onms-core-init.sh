#!/bin/bash
#
# Intended to be used as part of an InitContainer expecting the same Container Image as OpenNMS
# Designed for Horizon 29 or Meridian 2021 and 2022. Newer or older versions are not supported.
#
# External environment variables used by this script:
# CONFIG_DIR_OVERLAY (initialized by the caller script)
# CORTEX_BULKHEAD_MAX_WAIT_DURATION
# CORTEX_EXTERNAL_TAGS_CACHE_SIZE
# CORTEX_MAX_CONCURRENT_HTTP_CONNECTIONS
# CORTEX_METRIC_CACHE_SIZE
# CORTEX_ORGANIZATION_ID
# CORTEX_READ_TIMEOUT
# CORTEX_READ_URL
# CORTEX_WRITE_TIMEOUT
# CORTEX_WRITE_URL
# ELASTICSEARCH_INDEX_STRATEGY_FLOWS
# ELASTICSEARCH_PASSWORD
# ELASTICSEARCH_SERVER
# ELASTICSEARCH_USER
# ENABLE_ACLS
# ENABLE_ALEC
# ENABLE_CORTEX
# ENABLE_GRAFANA
# ENABLE_TELEMETRYD
# ENABLE_TSS_DUAL_WRITE
# KAFKA_BOOTSTRAP_SERVER
# KAFKA_SASL_MECHANISM
# KAFKA_SASL_PASSWORD
# KAFKA_SASL_USERNAME
# KAFKA_SECURITY_PROTOCOL
# OPENNMS_ADMIN_PASS
# OPENNMS_DATABASE_CONNECTION_IDLETIMEOUT
# OPENNMS_DATABASE_CONNECTION_LOGINTIMEOUT
# OPENNMS_DATABASE_CONNECTION_MINPOOL
# OPENNMS_DATABASE_CONNECTION_MAXPOOL
# OPENNMS_DATABASE_CONNECTION_MAXSIZE
# OPENNMS_DBNAME
# OPENNMS_DBPASS
# OPENNMS_DBUSER
# OPENNMS_INSTANCE_ID
# OPENNMS_RRAS
# OPENNMS_WEB_BASEURL_SCHEME
# POSTGRES_HOST
# POSTGRES_PASSWORD
# POSTGRES_PORT
# POSTGRES_SSL_FACTORY
# POSTGRES_SSL_MODE
# POSTGRES_USER

set -euo pipefail
trap 's=$?; echo >&2 "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

trap 'echo "Received SIGHUP: exiting."; exit 2' HUP
trap 'echo "Received SIGTERM: exiting."; exit 2' TERM

umask 002

function wait_for {
  echo "Waiting for $1"
  IFS=':' read -a data <<< $1
  until printf "" 2>>/dev/null >>/dev/tcp/${data[0]}/${data[1]}; do
    sleep 5
  done
  echo "Done"
}

function update_rras {
  if grep -q "[<]rrd" $1; then
    echo "  Updating RRAS in $1"
    sed -i -r "/[<]rra/d" $1
    sed -i -r "/[<]rrd/a $2" $1
  fi
}

echo "OpenNMS Core Configuration Script..."

# Requirements
command -v rsync >/dev/null 2>&1 || { echo >&2 "rsync is required but it's not installed. Aborting."; exit 1; }

# Defaults
OPENNMS_DATABASE_CONNECTION_IDLETIMEOUT="${OPENNMS_DATABASE_CONNECTION_IDLETIMEOUT:-600}"
OPENNMS_DATABASE_CONNECTION_LOGINTIMEOUT="${OPENNMS_DATABASE_CONNECTION_LOGINTIMEOUT:-3}"
OPENNMS_DATABASE_CONNECTION_MINPOOL="${OPENNMS_DATABASE_CONNECTION_MINSIZE:-25}"
OPENNMS_DATABASE_CONNECTION_MAXPOOL="${OPENNMS_DATABASE_CONNECTION_MAXPOOL:-50}"
OPENNMS_DATABASE_CONNECTION_MAXSIZE="${OPENNMS_DATABASE_CONNECTION_MAXSIZE:-50}"
OPENNMS_WEB_BASEURL_SCHEME="${OPENNMS_WEB_BASEURL_SCHEME:-https}"
KAFKA_SASL_MECHANISM="${KAFKA_SASL_MECHANISM:-PLAIN}"
KAFKA_SECURITY_PROTOCOL="${KAFKA_SECURITY_PROTOCOL:-SASL_PLAINTEXT}"

# Retrieve OpenNMS package name and version
if command -v unzip   >/dev/null 2>&1; then
PKG=$(unzip -q -c "/opt/opennms/lib/opennms_install.jar" installer.properties | grep "install.package.name"  | cut -d '=' -f 2)
VERSION=$(tail -1 "/opt/opennms/jetty-webapps/opennms/WEB-INF/version.properties" | cut -d '=' -f 2)
else
# Assume opennms PKG
PKG=opennms
VERSION=$(tail -1 "/opt/opennms/jetty-webapps/opennms/WEB-INF/version.properties" | cut -d '=' -f 2)
fi

if [[ "${PKG}" == "unknown" ]] || [[ "${PKG}" == "" ]]; then
  if [[ ! -e jetty-webapps/opennms/WEB-INF/version.properties ]]; then
    echo >&2 "Couldn't determine version number from package manager (which is normal for newer containers) and jetty-webapps/opennms/WEB-INF/version.properties does not exist. Aborting."; exit 1;
  fi
  VERSION=$(grep '^version\.display=' jetty-webapps/opennms/WEB-INF/version.properties | sed -e 's/^version.display=//' -e 's/#.*//')
  if [[ "$VERSION" == 20?? ]]; then
    PKG=meridian-assumed
  else
    PKG=horizon-assumed
  fi
fi

MAJOR=${VERSION%%.*}
echo "Package: ${PKG}"
echo "Version: ${VERSION}"
echo "Major: ${MAJOR}"

IFS=. read -r MAJOR MINOR PATCH <<<"$VERSION"
echo "Minor: ${MINOR}"
PATCH=${PATCH//-SNAPSHOT}
echo "Patch: ${PATCH}"


# Verify if Twin API is available
USE_TWIN="false"
if [[ "$PKG" == *"meridian"* ]]; then
  echo "OpenNMS Meridian $MAJOR detected"
  if (( $MAJOR > 2021 )); then
    USE_TWIN=true
  fi
elif [[ "$PKG" == *"opennms"* ]] && [[ $MAJOR -gt 2021 ]];then
  echo "OpenNMS Core $MAJOR detected"
  USE_TWIN=true
else
  echo "OpenNMS Core $MAJOR detected"
  if (( $MAJOR > 28 )); then
    USE_TWIN=true
  fi
fi
echo "Twin API Available? $USE_TWIN"

# Wait for dependencies
wait_for ${POSTGRES_HOST}:${POSTGRES_PORT}
if [[ -v KAFKA_BOOTSTRAP_SERVER ]]; then
  wait_for ${KAFKA_BOOTSTRAP_SERVER}
fi

CONFIG_DIR="/opennms-etc"          # Mounted externally
BACKUP_ETC="/opt/opennms/etc"      # Requires OpenNMS Image
OVERLAY_DIR="/opt/opennms-overlay" # Mounted Externally
DEPLOY_DIR="/opennms-deploy"       # Mounted Externally

CONFIG_DIR_OVERLAY=${OVERLAY_DIR}/etc

OVERLAY_CONFIG_MAPS="/opennms-overlay-configmaps"          # Mounted externally

KARAF_FILES=( \
"config.properties" \
"startup.properties" \
"custom.properties" \
"jre.properties" \
"profile.cfg" \
"jmx.acl.*" \
"org.apache.felix.*" \
"org.apache.karaf.*" \
"org.ops4j.pax.url.mvn.cfg" \
)

# Show permissions (debug purposes)
echo -n "Configuration directory permissions: "
ls -ld ${CONFIG_DIR}

### Initialize etc directory

# First, we need to handle updates from older Helm charts before we do anything else.
# Older charts (0.3.0 and before) didn't use helm-chart-configured, but only used
# OpenNMS' configured file. If configured exists, but no helm-chart-configured exists,
# assume we are updating from an older Helm chart and create helm-chart-configured.
if [ -f ${CONFIG_DIR}/configured ] && [ ! -f ${CONFIG_DIR}/helm-chart-configured ]; then
  echo "Upgrading from older Helm chart that has already been configured: creating ${CONFIG_DIR}/helm-chart-configured and ${CONFIG_DIR}/helm-chart-opennms-version."
  touch ${CONFIG_DIR}/helm-chart-configured
  echo "version not stored previously" > ${CONFIG_DIR}/helm-chart-opennms-version
fi

# Include all the configuration files that must be added once but could change after the first run
if [ ! -f ${CONFIG_DIR}/helm-chart-configured ]; then
  echo "Initializing configuration directory for the first time ..."
  rsync -arO --no-perms --no-owner --no-group --out-format="%n %C" ${BACKUP_ETC}/ ${CONFIG_DIR}/ | sed 's/^/  /'

  echo "Initialize default foreign source definition in ${CONFIG_DIR}/default-foreign-source.xml"
  cat <<EOF > ${CONFIG_DIR}/default-foreign-source.xml
<foreign-source xmlns="http://xmlns.opennms.org/xsd/config/foreign-source" name="default" date-stamp="2018-01-01T00:00:00.000-05:00">
  <scan-interval>1d</scan-interval>
  <detectors>
    <detector name="ICMP" class="org.opennms.netmgt.provision.detector.icmp.IcmpDetector"/>
    <detector name="SNMP" class="org.opennms.netmgt.provision.detector.snmp.SnmpDetector"/>
    <detector name="OpenNMS-JVM" class="org.opennms.netmgt.provision.detector.jmx.Jsr160Detector">
      <parameter key="port" value="18980"/>
      <parameter key="factory" value="PASSWORD-CLEAR"/>
      <parameter key="username" value="admin"/>
      <parameter key="password" value="admin"/>
      <parameter key="protocol" value="rmi"/>
      <parameter key="urlPath" value="/jmxrmi"/>
      <parameter key="timeout" value="3000"/>
      <parameter key="retries" value="2"/>
      <parameter key="type" value="default"/>
      <parameter key="ipMatch" value="127.0.0.1"/>
    </detector>
  </detectors>
  <policies>
    <policy name="Do Not Persist Discovered IPs" class="org.opennms.netmgt.provision.persist.policies.MatchingIpInterfacePolicy">
      <parameter key="action" value="DO_NOT_PERSIST"/>
      <parameter key="matchBehavior" value="NO_PARAMETERS"/>
    </policy>
    <policy name="Enable Data Collection" class="org.opennms.netmgt.provision.persist.policies.MatchingSnmpInterfacePolicy">
      <parameter key="action" value="ENABLE_COLLECTION"/>
      <parameter key="matchBehavior" value="ANY_PARAMETER"/>
      <parameter key="ifOperStatus" value="1"/>
    </policy>
  </policies>
</foreign-source>
EOF
  echo "Touching ${CONFIG_DIR}/helm-chart-configured to indicate that the Helm chart has been configured for the first time"
  touch ${CONFIG_DIR}/helm-chart-configured
else
  echo -n "Previous configuration found. Update policy opennms.configuration.etcUpdatePolicy == ${OPENNMS_ETC_UPDATE_POLICY}. "
  if [ "${OPENNMS_ETC_UPDATE_POLICY}" == "never" ]; then
     echo "Not updating etc files"
  elif [ "${OPENNMS_ETC_UPDATE_POLICY}" == "newer" ]; then
     echo "Synchronizing only newer files..."
     rsync -aruO --no-perms --no-owner --no-group --out-format="%n %C" ${BACKUP_ETC}/ ${CONFIG_DIR}/ | sed 's/^/  /'
  elif [ "${OPENNMS_ETC_UPDATE_POLICY}" == "new" ]; then
     echo "Synchronizing only new files..."
     rsync -arO --ignore-existing --no-perms --no-owner --no-group --out-format="%n %C" ${BACKUP_ETC}/ ${CONFIG_DIR}/ | sed 's/^/  /'
  else
     echo "Unsupported update policy '${OPENNMS_ETC_UPDATE_POLICY}'. Exiting." >&2
     exit 1
  fi
fi

# See if we are on a fresh install or a different version of OpenNMS and remove
# the "configured" file so the installer runs.
if [ ! -f ${CONFIG_DIR}/helm-chart-opennms-version ]; then
  previous_opennms="new Helm chart install"
else
  previous_opennms="$(<${CONFIG_DIR}/helm-chart-opennms-version)"
fi
current_opennms="${PKG}-${VERSION}"
if [ "${previous_opennms}" != "${current_opennms}" ]; then
  echo "OpenNMS version change detected from '${previous_opennms}' to '${current_opennms}': triggering installer to run by removing ${CONFIG_DIR}/configured file. Also updating version in ${CONFIG_DIR}/helm-chart-opennms-version."
  rm -f ${CONFIG_DIR}/configured # it might not already exist
  echo "${current_opennms}" > ${CONFIG_DIR}/helm-chart-opennms-version
else
  echo "No OpenNMS version change detected: still on '${current_opennms}'"
fi

# Guard against application upgrades
MANDATORY=/tmp/opennms-mandatory
mkdir -p ${MANDATORY}
echo "Backing up mandatory files..."
for file in "${KARAF_FILES[@]}"; do
  echo "  Backing up ${file} to ${MANDATORY}..."
  cp --force ${BACKUP_ETC}/${file} ${MANDATORY}/
done
# WARNING: if the volume behind CONFIG_DIR doesn't have the right permissions, the following fails
echo "Overriding mandatory files from ${MANDATORY} to ${CONFIG_DIR}..."
rsync -aO --no-perms --no-owner --no-group --out-format="%n %C" ${MANDATORY}/ ${CONFIG_DIR}/ | sed 's/^/  /'

# Initialize overlay
mkdir -p ${CONFIG_DIR_OVERLAY}/opennms.properties.d ${CONFIG_DIR_OVERLAY}/featuresBoot.d

# Apply common OpenNMS configuration settings
# Configure the instance ID
# Required when having multiple OpenNMS backends sharing a Kafka cluster or an Elasticsearch cluster.
if [ -n "${OPENNMS_INSTANCE_ID}" ]; then
  echo "Creating ${CONFIG_DIR_OVERLAY}/opennms.properties.d/instanceid.properties with our instance ID '${OPENNMS_INSTANCE_ID}'"
  cat <<EOF > ${CONFIG_DIR_OVERLAY}/opennms.properties.d/instanceid.properties
# Used for Kafka Topics and Elasticsearch Index Prefixes
org.opennms.instance.id=${OPENNMS_INSTANCE_ID}
EOF
else
  if [[ -e "${CONFIG_DIR}/opennms.properties.d/instanceid.properties" ]]; then
    echo "Found ${CONFIG_DIR}/opennms.properties.d/instanceid.properties, we are going to remove it."
    rm "${CONFIG_DIR}/opennms.properties.d/instanceid.properties"
  fi
fi

# Disable data choices (optional)
echo "Creating ${CONFIG_DIR_OVERLAY}/org.opennms.features.datachoices.cfg to disable data choices"
cat <<EOF > ${CONFIG_DIR_OVERLAY}/org.opennms.features.datachoices.cfg
enabled=false
acknowledged-by=admin
acknowledged-at=Sun Mar 01 00\:00\:00 EDT 2020
EOF

# Configure Database access
USE_UPDATED_DATASOURCE=false
if [ "${MAJOR}" -eq 32 ];then
  if [ "${MINOR}" -gt 0 ];then
    USE_UPDATED_DATASOURCE=true
  elif [ "${MINOR}" -eq 0 ] && [ "${PATCH}" -ge 4 ];then
    USE_UPDATED_DATASOURCE=true
  else
    USE_UPDATED_DATASOURCE=false
  fi
elif [ "${MAJOR}" -ge 33 ] && [ "${MAJOR}" -lt 2000 ]; then
  USE_UPDATED_DATASOURCE=true
else
  USE_UPDATED_DATASOURCE=false
fi
echo "Creating datasource configuration in ${CONFIG_DIR_OVERLAY}/opennms-datasources.xml (USE_UPDATED_DATASOURCE: $USE_UPDATED_DATASOURCE)"
cat <<EOF > ${CONFIG_DIR_OVERLAY}/opennms-datasources.xml
<?xml version="1.0" encoding="UTF-8"?>
<datasource-configuration xmlns:this="http://xmlns.opennms.org/xsd/config/opennms-datasources" 
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
  xsi:schemaLocation="http://xmlns.opennms.org/xsd/config/opennms-datasources 
  http://www.opennms.org/xsd/config/opennms-datasources.xsd ">

  <connection-pool factory="org.opennms.core.db.HikariCPConnectionFactory"
    idleTimeout="${OPENNMS_DATABASE_CONNECTION_IDLETIMEOUT}"
    loginTimeout="${OPENNMS_DATABASE_CONNECTION_LOGINTIMEOUT}"
    minPool="${OPENNMS_DATABASE_CONNECTION_MINPOOL}"
    maxPool="${OPENNMS_DATABASE_CONNECTION_MAXPOOL}"
    maxSize="${OPENNMS_DATABASE_CONNECTION_MAXSIZE}" />

  <jdbc-data-source name="opennms" 
                    database-name="${OPENNMS_DBNAME}" 
                    class-name="org.postgresql.Driver" 
                    url="jdbc:postgresql://${POSTGRES_HOST}:${POSTGRES_PORT}/${OPENNMS_DBNAME}?sslmode=${POSTGRES_SSL_MODE}&amp;sslfactory=${POSTGRES_SSL_FACTORY}"
                    user-name="${OPENNMS_DBUSER}"
                    password="${OPENNMS_DBPASS}" />

EOF
if $USE_UPDATED_DATASOURCE; then
cat <<EOF >> ${CONFIG_DIR_OVERLAY}/opennms-datasources.xml
  <jdbc-data-source name="opennms-admin" 
                    database-name="template1" 
                    class-name="org.postgresql.Driver" 
                    url="jdbc:postgresql://${POSTGRES_HOST}:${POSTGRES_PORT}/template1?sslmode=${POSTGRES_SSL_MODE}&amp;sslfactory=${POSTGRES_SSL_FACTORY}"
                    user-name="${POSTGRES_USER}"
                    password="${POSTGRES_PASSWORD}">
    <connection-pool idleTimeout="${OPENNMS_DATABASE_CONNECTION_IDLETIMEOUT}"
                     minPool="${OPENNMS_DATABASE_CONNECTION_MINPOOL}"
                     maxPool="${OPENNMS_DATABASE_CONNECTION_MAXPOOL}"
                     maxSize="${OPENNMS_DATABASE_CONNECTION_MAXSIZE}" />
  </jdbc-data-source>
  
  <jdbc-data-source name="opennms-monitor" 
                    database-name="postgres" 
                    class-name="org.postgresql.Driver" 
                    url="jdbc:postgresql://${POSTGRES_HOST}:${POSTGRES_PORT}/postgres?sslmode=${POSTGRES_SSL_MODE}&amp;sslfactory=${POSTGRES_SSL_FACTORY}"
                    user-name="${POSTGRES_USER}"
                    password="${POSTGRES_PASSWORD}">
    <connection-pool idleTimeout="${OPENNMS_DATABASE_CONNECTION_IDLETIMEOUT}"
                     minPool="${OPENNMS_DATABASE_CONNECTION_MINPOOL}"
                     maxPool="${OPENNMS_DATABASE_CONNECTION_MAXPOOL}"
                     maxSize="${OPENNMS_DATABASE_CONNECTION_MAXSIZE}" />
  </jdbc-data-source>
</datasource-configuration>
EOF
else
cat <<EOF >> ${CONFIG_DIR_OVERLAY}/opennms-datasources.xml
  <jdbc-data-source name="opennms-admin"
                    database-name="template1"
                    class-name="org.postgresql.Driver"
                    url="jdbc:postgresql://${POSTGRES_HOST}:${POSTGRES_PORT}/template1?sslmode=${POSTGRES_SSL_MODE}&amp;sslfactory=${POSTGRES_SSL_FACTORY}"
                    user-name="${POSTGRES_USER}"
                    password="${POSTGRES_PASSWORD}"/>
</datasource-configuration>
EOF
fi

# Enable storeByGroup to improve performance
# RRD Strategy is enabled by default
echo "Creating ${CONFIG_DIR_OVERLAY}/opennms.properties.d/rrd.properties to enable storeByGroup"
cat <<EOF > ${CONFIG_DIR_OVERLAY}/opennms.properties.d/rrd.properties
org.opennms.rrd.storeByGroup=true
EOF

# Configure Timeseries for Cortex if enabled
if [[ ${ENABLE_CORTEX} == "true" ]]; then
  echo "Creating ${CONFIG_DIR_OVERLAY}/opennms.properties.d/timeseries.properties"
  if [[ ${ENABLE_TSS_DUAL_WRITE} == "true" ]]; then
    # Do *not* set org.opennms.timeseries.strategy=integration but do make sure the file exists and is empty for later
    echo -n > ${CONFIG_DIR_OVERLAY}/opennms.properties.d/timeseries.properties
  else
    cat <<EOF > ${CONFIG_DIR_OVERLAY}/opennms.properties.d/timeseries.properties
org.opennms.timeseries.strategy=integration
EOF
  fi

  cat <<EOF >> ${CONFIG_DIR_OVERLAY}/opennms.properties.d/timeseries.properties
org.opennms.timeseries.tin.metatags.tag.node=\${node:label}
org.opennms.timeseries.tin.metatags.tag.location=\${node:location}
org.opennms.timeseries.tin.metatags.tag.geohash=\${node:geohash}
org.opennms.timeseries.tin.metatags.tag.ifDescr=\${interface:if-description}
org.opennms.timeseries.tin.metatags.tag.label=\${resource:label}
EOF

  echo "Creating ${CONFIG_DIR_OVERLAY}/org.opennms.plugins.tss.cortex.cfg"
  cat <<EOF > ${CONFIG_DIR_OVERLAY}/org.opennms.plugins.tss.cortex.cfg
writeUrl=${CORTEX_WRITE_URL}
readUrl=${CORTEX_READ_URL}
maxConcurrentHttpConnections=${CORTEX_MAX_CONCURRENT_HTTP_CONNECTIONS}
writeTimeoutInMs=${CORTEX_WRITE_TIMEOUT}
readTimeoutInMs=${CORTEX_READ_TIMEOUT}
metricCacheSize=${CORTEX_METRIC_CACHE_SIZE}
externalTagsCacheSize=${CORTEX_EXTERNAL_TAGS_CACHE_SIZE}
bulkheadMaxWaitDuration=${CORTEX_BULKHEAD_MAX_WAIT_DURATION}
EOF
  if [[ -v CORTEX_ORGANIZATION_ID ]] && [ -n "${CORTEX_ORGANIZATION_ID}" ]; then
    echo "organizationId=${CORTEX_ORGANIZATION_ID}" >> ${CONFIG_DIR_OVERLAY}/org.opennms.plugins.tss.cortex.cfg
  elif [ -n "${OPENNMS_INSTANCE_ID}" ]; then
    echo "organizationId=${OPENNMS_INSTANCE_ID}" >> ${CONFIG_DIR_OVERLAY}/org.opennms.plugins.tss.cortex.cfg
  fi

  mkdir -p ${CONFIG_DIR_OVERLAY}/featuresBoot.d

  echo "Creating ${CONFIG_DIR_OVERLAY}/featuresBoot.d/cortex.boot"
  cat <<EOF > ${CONFIG_DIR_OVERLAY}/featuresBoot.d/cortex.boot
opennms-plugins-cortex-tss wait-for-kar=opennms-cortex-tss-plugin
EOF

  if [[ ${ENABLE_TSS_DUAL_WRITE} == "true" ]]; then
    echo "Creating ${CONFIG_DIR_OVERLAY}/featuresBoot.d/timeseries.boot"
    cat <<EOF > ${CONFIG_DIR_OVERLAY}/featuresBoot.d/timeseries.boot
opennms-timeseries-api
EOF
  fi
else
  if [[ -e "${CONFIG_DIR}/featuresBoot.d/cortex.boot" ]];then
   echo "Found ${CONFIG_DIR}/featuresBoot.d/cortex.boot, we are going to remove it."
   rm "${CONFIG_DIR}/featuresBoot.d/cortex.boot"
  fi

  if [[ -e "${CONFIG_DIR}/featuresBoot.d/timeseries.boot" ]];then
   echo "Found ${CONFIG_DIR}/featuresBoot.d/timeseries.boot, we are going to remove it."
   rm "${CONFIG_DIR}/featuresBoot.d/timeseries.boot"
  fi
fi

  mkdir -p ${CONFIG_DIR_OVERLAY}/opennms.properties.d

# Enable ACLs
echo "Creating ${CONFIG_DIR_OVERLAY}/opennms.properties.d/acl.properties"
cat <<EOF > ${CONFIG_DIR_OVERLAY}/opennms.properties.d/acl.properties
org.opennms.web.aclsEnabled=${ENABLE_ACLS}
EOF

# Required changes in order to use HTTPS through Ingress
echo "Creating ${CONFIG_DIR_OVERLAY}/opennms.properties.d/webui.properties"
cat <<EOF > ${CONFIG_DIR_OVERLAY}/opennms.properties.d/webui.properties
opennms.web.base-url=${OPENNMS_WEB_BASEURL_SCHEME}://%x%c/
org.opennms.security.disableLoginSuccessEvent=true
org.opennms.web.defaultGraphPeriod=last_2_hour
EOF

# Configure Elasticsearch to allow Helm/Grafana to access Flow data
if [[ -v ELASTICSEARCH_SERVER ]]; then
  echo "Configuring Elasticsearch for Flows..."
  echo "Creating ${CONFIG_DIR_OVERLAY}/org.opennms.features.flows.persistence.elastic.cfg"
  cat <<EOF > ${CONFIG_DIR_OVERLAY}/org.opennms.features.flows.persistence.elastic.cfg
elasticUrl=https://${ELASTICSEARCH_SERVER}
globalElasticUser=${ELASTICSEARCH_USER}
globalElasticPassword=${ELASTICSEARCH_PASSWORD}
elasticIndexStrategy=${ELASTICSEARCH_INDEX_STRATEGY_FLOWS}
EOF
  if [ -n "${OPENNMS_INSTANCE_ID}" ]; then
    PREFIX=$(echo ${OPENNMS_INSTANCE_ID} | tr '[:upper:]' '[:lower:]')-
    cat <<EOF >> ${CONFIG_DIR_OVERLAY}/org.opennms.features.flows.persistence.elastic.cfg
indexPrefix=${PREFIX}
EOF
  fi
fi


# Collectd Optimizations
echo "Creating ${CONFIG_DIR_OVERLAY}/opennms.properties.d/collectd.properties"
cat <<EOF > ${CONFIG_DIR_OVERLAY}/opennms.properties.d/collectd.properties
# To get data as close as possible to PDP
org.opennms.netmgt.collectd.strictInterval=true
EOF

if [[ $(find ${DEPLOY_DIR} -type f  | wc -l) -gt 0 ]]; then
 cp ${DEPLOY_DIR}/*.kar /usr/share/opennms/deploy
fi

# Enable ALEC standalone
if [[ ${ENABLE_ALEC} == "true" ]]; then
  echo "Creating ${CONFIG_DIR_OVERLAY}/featuresBoot.d/alec.boot"
  cat <<EOF > ${CONFIG_DIR_OVERLAY}/featuresBoot.d/alec.boot
alec-opennms-standalone wait-for-kar=opennms-alec-plugin
EOF
else
  if [[ -e "${CONFIG_DIR}/featuresBoot.d/alec.boot" ]];then
   echo "Found ${CONFIG_DIR}/featuresBoot.d/alec.boot, we are going to remove it."
   rm "${CONFIG_DIR}/featuresBoot.d/alec.boot"
  fi
fi

# Configure Sink and RPC to use Kafka, and the Kafka Producer.
if [[ -v KAFKA_BOOTSTRAP_SERVER ]]; then
  echo "Configuring Kafka for IPC..."

  echo "Creating ${CONFIG_DIR_OVERLAY}/opennms.properties.d/amq.properties"
  cat <<EOF > ${CONFIG_DIR_OVERLAY}/opennms.properties.d/amq.properties
org.opennms.activemq.broker.disable=true
EOF

  echo "Creating ${CONFIG_DIR_OVERLAY}/opennms.properties.d/kafka.properties"
  cat <<EOF > ${CONFIG_DIR_OVERLAY}/opennms.properties.d/kafka.properties
org.opennms.core.ipc.strategy=kafka
EOF

  if [[ "$USE_TWIN" == "true" ]]; then
    cat <<EOF >> ${CONFIG_DIR_OVERLAY}/opennms.properties.d/kafka.properties

# TWIN
org.opennms.core.ipc.twin.kafka.bootstrap.servers=${KAFKA_BOOTSTRAP_SERVER}
EOF
    if [ -n "${OPENNMS_INSTANCE_ID}" ]; then
      cat <<EOF >> ${CONFIG_DIR_OVERLAY}/opennms.properties.d/kafka.properties
org.opennms.core.ipc.twin.kafka.group.id=${OPENNMS_INSTANCE_ID}-Core-Twin
EOF
    fi
  fi

  cat <<EOF >> ${CONFIG_DIR_OVERLAY}/opennms.properties.d/kafka.properties

# SINK
org.opennms.core.ipc.sink.initialSleepTime=60000
org.opennms.core.ipc.sink.kafka.bootstrap.servers=${KAFKA_BOOTSTRAP_SERVER}

# SINK Consumer (verify Kafka broker configuration)
org.opennms.core.ipc.sink.kafka.session.timeout.ms=30000
org.opennms.core.ipc.sink.kafka.max.poll.records=50

# RPC
org.opennms.core.ipc.rpc.kafka.bootstrap.servers=${KAFKA_BOOTSTRAP_SERVER}
org.opennms.core.ipc.rpc.kafka.ttl=30000
org.opennms.core.ipc.rpc.kafka.single-topic=true

# RPC Consumer (verify Kafka broker configuration)
org.opennms.core.ipc.rpc.kafka.request.timeout.ms=30000
org.opennms.core.ipc.rpc.kafka.session.timeout.ms=30000
org.opennms.core.ipc.rpc.kafka.max.poll.records=50
org.opennms.core.ipc.rpc.kafka.auto.offset.reset=latest

# RPC Producer (verify Kafka broker configuration)
org.opennms.core.ipc.rpc.kafka.acks=0
org.opennms.core.ipc.rpc.kafka.linger.ms=5
EOF

  if [ -n "${OPENNMS_INSTANCE_ID}" ]; then
    cat <<EOF >> ${CONFIG_DIR_OVERLAY}/opennms.properties.d/kafka.properties

# org.opennms.instance.id-prefixed groups for multi-tenant operation
org.opennms.core.ipc.sink.kafka.group.id=${OPENNMS_INSTANCE_ID}-Core-Sink
org.opennms.core.ipc.rpc.kafka.group.id=${OPENNMS_INSTANCE_ID}-Core-RPC
EOF
  fi

  MODULES="rpc sink"
  if [[ "$USE_TWIN" == "true" ]]; then
    MODULES="twin $MODULES"
  fi
  for module in $MODULES; do
    cat <<EOF >> ${CONFIG_DIR_OVERLAY}/opennms.properties.d/kafka.properties

# ${module^^} Security
org.opennms.core.ipc.$module.kafka.security.protocol=${KAFKA_SECURITY_PROTOCOL}
org.opennms.core.ipc.$module.kafka.sasl.mechanism=${KAFKA_SASL_MECHANISM}
EOF
    if [[ -v KAFKA_SASL_USERNAME ]] &&  [[ -v KAFKA_SASL_PASSWORD ]]; then
      if [[ -v KAFKA_SASL_MECHANISM ]] && [[ "${KAFKA_SASL_MECHANISM}" == *"SCRAM"* ]]; then
        JAAS_CLASS="org.apache.kafka.common.security.scram.ScramLoginModule"
      else
        JAAS_CLASS="org.apache.kafka.common.security.plain.PlainLoginModule"
      fi
      cat <<EOF >> ${CONFIG_DIR_OVERLAY}/opennms.properties.d/kafka.properties
org.opennms.core.ipc.$module.kafka.sasl.jaas.config=${JAAS_CLASS} required username="${KAFKA_SASL_USERNAME}" password="${KAFKA_SASL_PASSWORD}";
EOF
    fi
  done
fi

# Configure RRAs
if [[ -v OPENNMS_RRAS ]]; then
  IFS=';' read -a RRAS <<< ${OPENNMS_RRAS}
  RRACFG=""
  for RRA in ${RRAS[@]}; do
    RRACFG+="<rra>${RRA}</rra>"
  done
  echo "Configuring RRAs..."
  echo "  RRA config: ${RRACFG}"
  for XML in $(find ${CONFIG_DIR} -name '*datacollection*.xml' -or -name '*datacollection*.d'); do
    if [ -d $XML ]; then
      for XML in $(find ${XML} -name '*.xml'); do
        update_rras ${XML} ${RRACFG}
      done
    else
      update_rras ${XML} ${RRACFG}
    fi
  done
fi

# Disable Telemetryd
if [[ ${ENABLE_TELEMETRYD} == "false" ]]; then
  echo "Disable telemetryd in ${CONFIG_DIR}/org.apache.karaf.features.cfg"
  sed -i -r '/opennms-flows/d' ${CONFIG_DIR}/org.apache.karaf.features.cfg
fi

# Cleanup temporary requisition files
echo "Removing temporary requisition files in ${CONFIG_DIR}/imports/pending/*.xml.* and ${CONFIG_DIR}/foreign-sources/pending/*.xml.*"
rm -f ${CONFIG_DIR}/imports/pending/*.xml.*
rm -f ${CONFIG_DIR}/foreign-sources/pending/*.xml.*

if [[ ${ENABLE_GRAFANA} == "true" ]]; then
  # Configure Grafana
  if [[ -e /scripts/onms-grafana-init.sh ]]; then
    source /scripts/onms-grafana-init.sh
  else
    echo "Warning: cannot find onms-grafana-init.sh"
  fi
else
  echo "Grafana is not enabled, not running onms-grafana-init.sh"
  if [[ -e "${CONFIG_DIR}/opennms.properties.d/grafana.properties" ]];then
   echo "Found ${CONFIG_DIR}/opennms.properties.d/grafana.properties, we are going to remove it."
   rm "${CONFIG_DIR}/opennms.properties.d/grafana.properties"
  fi
fi

echo "Updating admin password in ${CONFIG_DIR}/users.xml"
if [[ -e "/opt/opennms/bin/password" ]];then 
   cp ${CONFIG_DIR}/users.xml /opt/opennms/etc/users.xml 
   echo "RUNAS=$(whoami)" > /opt/opennms/etc/opennms.conf
   /opt/opennms/bin/runjava -s -q 
   /opt/opennms/bin/password "admin" "${OPENNMS_ADMIN_PASS}"
   rm /opt/opennms/etc/opennms.conf /opt/opennms/etc/java.conf
   cp /opt/opennms/etc/users.xml ${CONFIG_DIR}/users.xml
elif command -v perl   >/dev/null 2>&1; then
 perl /scripts/onms-set-admin-password.pl ${CONFIG_DIR}/users.xml admin "${OPENNMS_ADMIN_PASS}"
else
 echo "We are unable to update Admin password. Exiting."
 exit 1
fi

if [ -d ${OVERLAY_CONFIG_MAPS} ]; then
  echo "Processing overlay config maps ..."
  # We need to make sure the directories are numerically sorted to match the configured configmap order.
  for dir in $(ls -1d ${OVERLAY_CONFIG_MAPS}/* | sort -t/ -k3 -n); do
    if [[ $(basename $dir) =~ .*-unzip ]]; then
      for zip in $(ls -1 ${dir}/*.zip | sort); do
        echo "  Extracting files from $zip to ${OVERLAY_DIR}/ ..."
        unzip -o -d ${OVERLAY_DIR} ${zip} | sed 's/^/    /'
      done
    else
      # When we first copy off of the configmap volume, we copy symlinks as files and ignore Kubernetes configmap volume ".." files.
      # See: https://github.com/spring-projects/spring-boot/issues/23232
      echo "  Copying files from $dir to ${OVERLAY_DIR}/ ..."
      rsync -arO -L --exclude='..*' --no-perms --no-owner --no-group --out-format="%n %C" $dir/ ${OVERLAY_DIR}/ | sed 's/^/    /'
    fi
  done
fi
