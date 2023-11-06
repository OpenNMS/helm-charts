# OpenNMS Helm Charts -- Minion

This template can be used to bring up a minion and connect it to a OpenNMS core.

## Requirements:
* OpenNMS Core with Kafka connection configured

## How to use:
* Modify `values.yaml` file:
* (If you are using JKS) add a base64 value of Java Keystore into `content`. You can get the base64 value by running `cat jks/truststore.jks | base64`

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| core.instanceID | string | `"monms"` |  |
| minion.configuration.ports.karaf.enabled | bool | `true` |  |
| minion.configuration.ports.karaf.externalPort | int | `8201` |  |
| minion.configuration.ports.syslog.enabled | bool | `true` |  |
| minion.configuration.ports.syslog.externalPort | int | `1514` |  |
| minion.configuration.ports.trapd.enabled | bool | `true` |  |
| minion.configuration.ports.trapd.externalPort | int | `1162` |  |
| minion.configuration.storage.dataFolder | string | `"5Gi"` |  |
| minion.image.pullPolicy | string | `"IfNotPresent"` |  |
| minion.image.repository | string | `"opennms/minion"` |  |
| minion.image.tag | string | `""` |  |
| minion.kafkaBroker.address | string | `"onms-kafka-bootstrap.shared.svc:9093"` |  |
| minion.kafkaBroker.password | string | `""` |  |
| minion.kafkaBroker.username | string | `""` |  |
| minion.location | string | `"pod"` |  |
| minion.name | string | `"myminion"` |  |
| minion.resources.limits.cpu | string | `"2"` |  |
| minion.resources.limits.memory | string | `"8Gi"` |  |
| minion.resources.requests.cpu | string | `"2"` |  |
| minion.resources.requests.memory | string | `"4Gi"` |  |
| truststore.content | string | `""` |  |
| truststore.password | string | `""` |  |