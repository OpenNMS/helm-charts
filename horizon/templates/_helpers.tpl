{{/*
Expand the name of the chart.
*/}}
{{- define "core.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "core.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "core.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "core.labels" -}}
helm.sh/chart: {{ include "core.chart" . }}
{{ include "core.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "core.selectorLabels" -}}
app.kubernetes.io/name: {{ include "core.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "core.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "core.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Define custom content for JVM_OPTS to conditionally handle Truststores
*/}}
{{- define "core.jvmOptions" -}}
  {{- $common := "-XX:+AlwaysPreTouch -XX:+UseG1GC -XX:+UseStringDeduplication" }}
  {{- if and .Values.dependencies.truststore .Values.dependencies.truststore.content }}
    {{- $truststore := "-Djavax.net.ssl.trustStore=/etc/java/jks/truststore.jks" }}
    {{- $password := "" }}
    {{- if .Values.dependencies.truststore.password }}
      {{- $password = "-Djavax.net.ssl.trustStorePassword=$(TRUSTSTORE_PASSWORD)" }}
    {{- end }}
    {{- printf "%s %s %s" $common $truststore $password }}
  {{- else -}}
    {{- $common }}
  {{- end }}
{{- end }}

{{/*
Define whether RRD is enabled
*/}}
{{- define "core.enableTssDualWrite" -}}
  {{ or (not .Values.core.configuration.enableCortex) .Values.core.configuration.enableTssDualWrite -}}
{{- end }}

{{/*
Define common content for Grafana Promtail
*/}}
{{- define "core.promtailBaseConfig" -}}
{{- $scheme := "http" -}}
{{- if ((.Values.dependencies).loki).caCert -}}
  {{- $scheme := "https" -}}
{{- end -}}
server:
  http_listen_port: 9080
  grpc_listen_port: 0
clients:
- tenant_id: {{ .Release.Name }}
  url: {{ printf "%s://%s:%d/loki/api/v1/push" $scheme ((.Values.dependencies).loki).hostname (((.Values.dependencies).loki).port | int) }}
  {{- if and ((.Values.dependencies).loki).username ((.Values.dependencies).loki).password }}
  basic_auth:
    username: {{ .Values.dependencies.loki.username }}
    password: {{ .Values.dependencies.loki.password }}
  {{- end }}
  {{- if ((.Values.dependencies).loki).caCert }}
  tls_config:
    ca_file: /etc/jks/loki-ca.cert
  {{- end }}
  external_labels:
    namespace: {{ include "namespace" . }}
scrape_configs:
- job_name: system
  pipeline_stages:
  - multiline:
      firstline: '^\d{4}-\d{2}-\d{2}'
      max_wait_time: 3s
  static_configs:
  - targets:
    - localhost
{{- end }}

{{/*
Define Customer/Environment Domain
*/}}
{{- define "core.domain" -}}
{{- printf "%s.%s" .Release.Name .Values.domain -}}
{{- end }}

{{/*
SecurityContextConstraints apiVersion
*/}}
{{- define "scc.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "security.openshift.io/v1" -}}
security.openshift.io/v1
{{- end }}
{{- end }}

{{/*
Are we running in an Red Hat OpenShift cluster?
*/}}
{{- define "onOpenShift" -}}
{{- $sccApiVersion := include "scc.apiVersion" . -}}
{{- if not (empty $sccApiVersion) }}
{{- printf "true" -}}
{{- else }}
{{- printf "false" -}}
{{- end }}
{{- end }}

{{/*
Define Namespace
*/}}
{{- define "namespace" -}}
{{- if .Values.releaseNamespace }}
{{- printf "%s" .Release.Name -}}
{{- else }}
{{- printf "%s" .Release.Namespace -}}
{{- end }}
{{- end }}
