job "egress" {
  group "egress" {
    network {
      port "http" {
        static = 80
        to     = 80
      }
      port "https" {
        static = 443
        to     = 443
      }
    }
    ephemeral_disk {
      migrate = true
      size = 500
      sticky = true
    }
    service {
      name = "caddy-https"
      port = "https"
    }
    service {
      name = "caddy-http"
      port = "http"
    }
    task "caddy" {
      driver = "docker"
      env {
        XDG_DATA_HOME = "${NOMAD_ALLOC_DIR}/data/"
      }
      config {
        image = "caddy:2.7-alpine"
        ports = ["http", "https"]
        mount {
          type   = "bind"
          source = "configs"
          target = "/etc/caddy"
        }
      }
      template {
        data = <<EOT
nomad.{{ {
  reverse_proxy localhost:4646
}
{{- range nomadService "fvtt-instance" }}
{{ .Domain }} {
  redir / /-/ permanent
  reverse_proxy /-/* {{ .FvttDestination }}
}{{- end }}
EOT
        destination = "configs/Caddyfile"
        change_mode = "script"
        change_script {
          command = "caddy"
          args    = ["reload", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
        }
      }
      resources {
        cpu = 500
        memory = 500
      }
    }
  }
}
