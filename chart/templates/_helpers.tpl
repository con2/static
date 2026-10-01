{{- define "static.labels" -}}
stack: static
{{- end -}}

{{/* Gateway listener name for a site; also the HTTPRoute parentRef sectionName. */}}
{{- define "static.listenerName" -}}
https-{{ . }}
{{- end -}}
