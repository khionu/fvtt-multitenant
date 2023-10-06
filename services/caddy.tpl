{{- range nomadService "fvtt-instance" }}
{{ .Domain }} {
  redir / /-/ permanent
  reverse_proxy /-/* {{ .FvttDestination }}
}{{- end }}

