# OpenNMS Helm Charts -- Horizon

OpenNMS Helm Charts makes it easier for users to run OpenNMS Horizon locally in a Kubernetes cluster or Red Hat OpenShift.

Each deployment through OpenNMS Helm Charts has a single Core server, Grafana, and a custom Ingress that shares the RRD files and some configuration files, and multiple Sentinels for flow processing.

Note that this is one way to approach the solution.
We recommend that you study the content of the Helm chart and tune it for your needs.

For more information about deploying in a containerized environment, including requirements and external dependencies, refer to [Containerized Deployment](https://docs.opennms.com/horizon/latest/deployment/core/containers.html) in the main product documentation.

If you are not already familiar with Horizon, we recommend reviewing our [product documentation](https://docs.opennms.com/horizon/32/deployment/core/introduction.html) and our [Horizon website](https://www.opennms.com/horizon/).

## Quick Start

Use the following commands to bring up an instance of Horizon for testing:

```
helm repo add opennms https://opennms.github.io/helm-charts

helm install monms opennms/horizon --set domain=domain1.com  --create-namespace
```

## Version compatibility

| Helm chart version | Horizon version(s) | Meridian version(s) |
| ----------- | ----------- | ----------- |
| 1.x | Horizon 32.x | Meridian 2023.x |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| core.configuration.affinity | string | `nil` |  |
| core.configuration.alecImage | object | `{}` |  |
| core.configuration.alwaysRollDeployment | bool | `true` |  |
| core.configuration.cortexTssImage | object | `{}` |  |
| core.configuration.database.password | string | `"0p3nNM5"` |  |
| core.configuration.database.poolSize | int | `50` |  |
| core.configuration.database.username | string | `"opennms"` |  |
| core.configuration.enableAcls | bool | `false` |  |
| core.configuration.enableAlec | bool | `false` |  |
| core.configuration.enableCortex | bool | `false` |  |
| core.configuration.enableTssDualWrite | bool | `false` |  |
| core.configuration.etcUpdatePolicy | string | `"never"` |  |
| core.configuration.http.adminPassword | string | `"admin"` |  |
| core.configuration.http.restPassword | string | `"admin"` |  |
| core.configuration.http.restUsername | string | `"opennms"` |  |
| core.configuration.nodeSelector | string | `nil` |  |
| core.configuration.rras[0] | string | `"RRA:AVERAGE:0.5:1:2016"` |  |
| core.configuration.rras[1] | string | `"RRA:AVERAGE:0.5:12:1488"` |  |
| core.configuration.rras[2] | string | `"RRA:AVERAGE:0.5:288:366"` |  |
| core.configuration.rras[3] | string | `"RRA:MAX:0.5:288:366"` |  |
| core.configuration.rras[4] | string | `"RRA:MIN:0.5:288:366"` |  |
| core.configuration.storage.etc | string | `"1Gi"` |  |
| core.configuration.storage.mibs | string | `nil` |  |
| core.configuration.storage.rrd | string | `"1000Gi"` |  |
| core.configuration.tolerations | string | `nil` |  |
| core.image.pullPolicy | string | `"IfNotPresent"` |  |
| core.image.repository | string | `"opennms/horizon"` |  |
| core.image.tag | string | `""` |  |
| core.inspector.enabled | bool | `false` |  |
| core.postConfigJob.ttlSecondsAfterFinished | int | `300` |  |
| core.resources.limits.cpu | string | `"2"` |  |
| core.resources.limits.memory | string | `"8Gi"` |  |
| core.resources.requests.cpu | string | `"2"` |  |
| core.resources.requests.memory | string | `"4Gi"` |  |
| core.terminationGracePeriodSeconds | int | `120` |  |
| createNamespace | bool | `false` |  |
| dependencies.clusterRole | bool | `true` |  |
| dependencies.clusterRoleBinding | bool | `true` |  |
| dependencies.cortex.bulkheadMaxWaitDuration | string | `"9223372036854775807"` |  |
| dependencies.cortex.externalTagsCacheSize | int | `1000` |  |
| dependencies.cortex.maxConcurrentHttpConnections | int | `100` |  |
| dependencies.cortex.metricCacheSize | int | `1000` |  |
| dependencies.cortex.readTimeoutInMs | int | `1000` |  |
| dependencies.cortex.readUrl | string | `"http://cortex-query-frontend.shared.svc.cluster.local:8080/prometheus/api/v1"` |  |
| dependencies.cortex.writeTimeoutInMs | int | `1000` |  |
| dependencies.cortex.writeUrl | string | `"http://cortex-distributor.shared.svc.cluster.local:8080/api/v1/push"` |  |
| dependencies.elasticsearch.configuration.flows.indexStrategy | string | `"daily"` |  |
| dependencies.elasticsearch.configuration.flows.numShards | int | `1` |  |
| dependencies.elasticsearch.configuration.flows.replicationFactor | int | `0` |  |
| dependencies.elasticsearch.hostname | string | `""` |  |
| dependencies.elasticsearch.password | string | `"31@st1c"` |  |
| dependencies.elasticsearch.port | int | `9200` |  |
| dependencies.elasticsearch.username | string | `"elastic"` |  |
| dependencies.kafka.configuration.saslMechanism | string | `"SCRAM-SHA-512"` |  |
| dependencies.kafka.configuration.securityProtocol | string | `"SASL_SSL"` |  |
| dependencies.kafka.hostname | string | `""` |  |
| dependencies.kafka.password | string | `"0p3nNM5"` |  |
| dependencies.kafka.port | int | `9093` |  |
| dependencies.kafka.username | string | `"opennms"` |  |
| dependencies.loki.caCert | string | `""` |  |
| dependencies.loki.hostname | string | `""` |  |
| dependencies.loki.password | string | `""` |  |
| dependencies.loki.port | int | `3100` |  |
| dependencies.loki.username | string | `""` |  |
| dependencies.postgresql.caCert | string | `""` |  |
| dependencies.postgresql.hostname | string | `"onms-db.shared.svc"` |  |
| dependencies.postgresql.password | string | `"P0stgr3s"` |  |
| dependencies.postgresql.port | int | `5432` |  |
| dependencies.postgresql.sslfactory | string | `"org.postgresql.ssl.LibPQFactory"` |  |
| dependencies.postgresql.sslmode | string | `"require"` |  |
| dependencies.postgresql.username | string | `"postgres"` |  |
| dependencies.route | bool | `true` |  |
| dependencies.securitycontext.allowPrivilegeEscalation | bool | `true` |  |
| dependencies.securitycontext.allowedCapabilities[0] | string | `"NET_BIND_SERVICE"` |  |
| dependencies.securitycontext.allowedCapabilities[1] | string | `"CAP_NET_RAW"` |  |
| dependencies.securitycontext.securitycontextconstraints.enabled | bool | `true` |  |
| dependencies.securitycontext.securitycontextconstraints.name | string | `"opennms-scc"` |  |
| dependencies.securitycontext.serviceaccount.enabled | bool | `true` |  |
| dependencies.securitycontext.serviceaccount.name | string | `"opennms-sa"` |  |
| dependencies.truststore.content | string | `""` |  |
| dependencies.truststore.password | string | `"0p3nNM5"` |  |
| domain | string | `"example.com"` |  |
| grafana.configuration.database.image.pullPolicy | string | `"IfNotPresent"` |  |
| grafana.configuration.database.image.repository | string | `"postgres"` |  |
| grafana.configuration.database.image.tag | string | `"13"` |  |
| grafana.configuration.database.password | string | `"Gr@f@n@"` |  |
| grafana.configuration.database.sslmode | string | `"require"` |  |
| grafana.configuration.database.username | string | `"grafana"` |  |
| grafana.configuration.ui.adminPassword | string | `"admin"` |  |
| grafana.image.pullPolicy | string | `"IfNotPresent"` |  |
| grafana.image.repository | string | `"opennms/helm"` |  |
| grafana.image.tag | string | `"9.0.10"` |  |
| grafana.imageRenderer.image.pullPolicy | string | `"IfNotPresent"` |  |
| grafana.imageRenderer.image.repository | string | `"grafana/grafana-image-renderer"` |  |
| grafana.imageRenderer.image.tag | string | `"latest"` |  |
| grafana.imageRenderer.replicaCount | int | `2` |  |
| grafana.imageRenderer.resources.limits.cpu | string | `"200m"` |  |
| grafana.imageRenderer.resources.limits.memory | string | `"256Mi"` |  |
| grafana.imageRenderer.resources.requests.cpu | string | `"100m"` |  |
| grafana.imageRenderer.resources.requests.memory | string | `"128Mi"` |  |
| grafana.replicaCount | int | `0` |  |
| grafana.resources.limits.cpu | string | `"200m"` |  |
| grafana.resources.limits.memory | string | `"1Gi"` |  |
| grafana.resources.requests.cpu | string | `"100m"` |  |
| grafana.resources.requests.memory | string | `"1Gi"` |  |
| imagePullSecrets | list | `[]` |  |
| ingress.annotations | object | `{}` |  |
| ingress.certManager.clusterIssuer | string | `"opennms-issuer"` |  |
| ingress.className | string | `"nginx"` |  |
| promtail.image.pullPolicy | string | `"IfNotPresent"` |  |
| promtail.image.repository | string | `"grafana/promtail"` |  |
| promtail.image.tag | string | `"latest"` |  |
| promtail.resources.limits.cpu | string | `"50m"` |  |
| promtail.resources.limits.memory | string | `"64Mi"` |  |
| sentinel.configuration.database.poolSize | int | `25` |  |
| sentinel.image.pullPolicy | string | `"IfNotPresent"` |  |
| sentinel.image.repository | string | `"opennms/sentinel"` |  |
| sentinel.image.tag | string | `""` |  |
| sentinel.replicaCount | int | `0` |  |
| sentinel.resources.limits.cpu | string | `"2"` |  |
| sentinel.resources.limits.memory | string | `"4Gi"` |  |
| sentinel.resources.requests.cpu | string | `"2"` |  |
| sentinel.resources.requests.memory | string | `"2Gi"` |  |
| sentinel.terminationGracePeriodSeconds | int | `60` |  |
| timezone | string | `"America/New_York"` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.11.3](https://github.com/norwoodj/helm-docs/releases/v1.11.3)
