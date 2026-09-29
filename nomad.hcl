job "md-libretranslate" {
  type = "service"

  group "MD-LibreTranslate" {
    count = 1

    restart {
      attempts = 2
      interval = "5m"
      delay    = "15s"
      mode     = "fail"
    }

    reschedule {
      attempts       = 2
      interval       = "10m"
      delay          = "30s"
      delay_function = "constant"
      unlimited      = false
    }

    network {
      port "node" {
        to = 5000
      }
    }

    service {
      name     = "md-libretranslate"
      port     = "node"
      provider = "nomad"

      check {
        type     = "http"
        # LibreTranslate has no dedicated /health endpoint; /languages is a lightweight GET
        # that only succeeds once language models are loaded and the API is ready to serve.
        path     = "/languages"
        interval = "30s"
        timeout  = "3s"
      }
    }

    task "md-libretranslate" {
      driver = "podman"
      config {
          image      = "localhost/libretranslate:1.9.6"
          force_pull = false
          ports      = ["node"]
      }
      env {
        # Bind to Nomad's per-allocation assigned port, not the image's default 5000.
        LT_HOST = "0.0.0.0"
        LT_PORT = "${NOMAD_PORT_node}"
      }
      resources {
        memory = 2000  # Memory in MB - loads translation models for every language pair
        cpu    = 1000  # CPU shares (1000 = 100% of 1 CPU)
      }
    }
  }
}
