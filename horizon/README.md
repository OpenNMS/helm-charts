# OpenNMS Helm Charts -- Horizon

If your organization uses Kubernetes or Red Hat OpenShift, OpenNMS makes a Helm chart available to simplify deployment of Horizon and Meridian.

Note that this is one way to approach the solution.
We recommend that you study the content of the Helm chart and tune it for your needs.

For more information about deploying in a containerized environment, including requirements and external dependencies, refer to [Containerized Deployment](https://docs.opennms.com/horizon/latest/deployment/core/containers.html) in the main product documentation.

If you are not already familiar with Horizon or Meridian, we recommend reviewing our product documentation ([Horizon](https://docs.opennms.com/horizon/latest/deployment/core/introduction.html), [Meridian](https://docs.opennms.com/meridian/latest/deployment/core/introduction.html)) and our [Horizon](https://www.opennms.com/horizon/) or [Meridian](https://www.opennms.com/meridian/) websites.

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

## Overlay ConfigMaps

The chart supports specifying a list of ConfigMaps with `core.overlayConfigMaps` that will be copied to the OpenNMS container overlay directory in the init container. This can be used to provide configuration files for OpenNMS. There are two ways to provide content in each ConfigMap:

### Plain files

Provide one or more plain files (text and/or binary) in the ConfigMap and specify the directory where these files will be copied.

Here is a configuration example:

```
core:
  overlayConfigMaps:
    - name: "my-etc-files"
      path: "etc"
```

Here is an example of how to create the ConfigMap:

```
instance=<helm release name> # make sure to set to your Helm release name
configmap=my-etc-files

mkdir etc
date > etc/testing-configmap

kubectl create configmap -n $instance $configmap --from-file=etc
```

### ZIP files

Provide one or more ZIP files in the ConfigMap, and each will be extracted in alphabetical order at the root of the overlay directory.

Here is a configuration example:

```
core:
  overlayConfigMaps:
    - name: "my-zip-files"
      unzip: true
```

Here is an example of how to create the ConfigMap:

```
instance=<helm release name> # make sure to set to your Helm release name
configmap=my-zip-files

mkdir -p zip/etc
dd if=/dev/zero bs=1k count=5000 of=zip/etc/lots-of-zeros # make a 5 MB test file
( cd zip && zip -r -o ../lots-of-zeros.zip . )

kubectl create configmap -n $instance $configmap --from-file=lots-of-zeros.zip
```

### Overlay ConfigMap Notes

1. This mechanism can be used only to *add* files. When `etc` files are copied into the `onms-etc-pvc` PVC, removing a file from the ConfigMap will not cause the file in the PVC to be deleted. In this case, you will need to delete the file manually after updating the ConfigMap to remove the file. You can do this with `kubectl exec -n $instance onms-core-0 -- rm etc/testing-configmap`.
2. ConfigMaps cannot contain recursive directory structures--only files. If you need to put files into multiple directories, each directory will need to be its own ConfigMap. `kubectl create configmap` will silently ignore subdirectories.
3. ConfigMaps can't be larger than 1 MB (see the note [here](https://kubernetes.io/docs/concepts/configuration/configmap/#motivation). If you have more content, you will need to split it across multiple ConfigMaps or compressed into ZIP files.
4. Use `kubectl delete configmap -n $instance $configmap` to delete an existing ConfigMap before updating.
5. After updating a ConfigMap, you will need to restart the pod; for example, `kubectl rollout restart -n $instance statefulset/onms-core`
6. You can use `kubectl get configmap -n $instance $configmap -o yaml` to view the ConfigMap that is created.
7. Due to file ownership, some files/directories might not be updatable in the container at runtime. A workaround is to build a modified container that updates permissions with `chmod -R g=u ...` on the affected files/directories. See the OpenNMS [core Dockerfile](https://github.com/OpenNMS/opennms/blob/develop/opennms-container/core/Dockerfile) for which directories have been updated to allow writes out of the box.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| core.configuration.affinity | string | `nil` |  |
| core.configuration.alecImage | object | `{}` |  |
| core.configuration.alwaysRollDeployment | bool | `true` |  |
| core.configuration.cortexTssImage | object | `{}` |  |
| core.configuration.database.password | string | `"0p3nNM5"` |  |
| core.configuration.database.idleTimeout | int | `3` |  |
| core.configuration.database.loginTimeout | int | `600` |  |
| core.configuration.database.minPool | int | `25` |  |
| core.configuration.database.maxPool | int | `50` |  |
| core.configuration.database.maxSize | int | `50` |  |
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
| core.configuration.ports.karaf.enabled | bool | `true` |  |
| core.configuration.ports.karaf.externalPort | int | `8101` |  |
| core.configuration.ports.syslog.enabled | bool | `true` |  |
| core.configuration.ports.syslog.externalPort | int | `10514` |  |
| core.configuration.ports.trapd.enabled | bool | `true` |  |
| core.configuration.ports.trapd.externalPort | int | `1162` |  |
| core.configuration.rras[0] | string | `"RRA:AVERAGE:0.5:1:2016"` |  |
| core.configuration.rras[1] | string | `"RRA:AVERAGE:0.5:12:1488"` |  |
| core.configuration.rras[2] | string | `"RRA:AVERAGE:0.5:288:366"` |  |
| core.configuration.rras[3] | string | `"RRA:MAX:0.5:288:366"` |  |
| core.configuration.rras[4] | string | `"RRA:MIN:0.5:288:366"` |  |
| core.configuration.storage.etc | string | `"1Gi"` |  |
| core.configuration.storage.mibs | string | `nil` |  |
| core.configuration.storage.rrd | string | `"1000Gi"` |  |
| core.configuration.timeSeriesStrategy | string | `"rrd"` |  |
| core.configuration.tolerations | string | `nil` |  |
| core.env | object | `{}` | Environment variables to set on the onms container. |
| core.image.pullPolicy | string | `"IfNotPresent"` |  |
| core.image.repository | string | `"opennms/horizon"` |  |
| core.image.tag | string | `""` |  |
| core.initContainers | list | `[]` | Experimental: a list of additional init containers |
| core.inspector.enabled | bool | `false` |  |
| core.overlayConfigMaps | list | `[]` |  |
| core.postConfigJob.ttlSecondsAfterFinished | int | `300` |  |
| core.resources.limits.cpu | string | `"2"` |  |
| core.resources.limits.memory | string | `"8Gi"` |  |
| core.resources.requests.cpu | string | `"2"` |  |
| core.resources.requests.memory | string | `"4Gi"` |  |
| core.terminationGracePeriodSeconds | int | `120` |  |
| createNamespace | bool | `false` | Whether to create the namespace when releaseNamespace=true. Has no effect otherwise. |
| dependencies.clusterRole | bool | `true` |  |
| dependencies.clusterRoleBinding | bool | `true` |  |
| dependencies.cortex.bulkheadMaxWaitDuration | string | `"9223372036854775807"` |  |
| dependencies.cortex.externalTagsCacheSize | int | `1000` |  |
| dependencies.cortex.maxConcurrentHttpConnections | int | `100` |  |
| dependencies.cortex.metricCacheSize | int | `1000` |  |
| dependencies.cortex.organizationId | string | `""` | Specify the `X-Scope-OrgID` header. This will override the tenant name when multiTenant=true. |
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
| multiTenant | bool | `false` | Enable multi-tenant mode. This will use the release name as the per-tenant identifier for the OpenNMS instance ID, databases, Kakfa topics, ElasticSearch indices, and Prometheus organization ID. |
| promtail.image.pullPolicy | string | `"IfNotPresent"` |  |
| promtail.image.repository | string | `"grafana/promtail"` |  |
| promtail.image.tag | string | `"latest"` |  |
| promtail.resources.limits.cpu | string | `"50m"` |  |
| promtail.resources.limits.memory | string | `"64Mi"` |  |
| releaseNamespace | bool | `false` | Install resource objects into namespace named for the Helm release. See also createNamespace. |
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
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
