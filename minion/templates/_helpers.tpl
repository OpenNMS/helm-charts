{{/*
SecurityContextConstraints apiVersion
*/}}
{{- define "scc.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "security.openshift.io/v1" -}}
security.openshift.io/v1
{{- end }}
{{- end }}

{{/*
Are we running in an OpenShift cluster.
*/}}
{{- define "onOpenShift" -}}
{{- $sccApiVersion := include "scc.apiVersion" . -}}
{{- if not (empty $sccApiVersion) }}
{{- printf "true" -}}
{{- else }}
{{- printf "false" -}}
{{- end }}
{{- end }}
