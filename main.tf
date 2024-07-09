locals {
  create_http_forward = var.http_forward || var.https_redirect
  default_service     = var.health_check["type"] == "tcp" ? google_compute_region_backend_service.tcp[0].id : var.health_check["type"] == "http" ? google_compute_region_backend_service.http[0].id : google_compute_region_backend_service.https[0].id
}

### Create Forwading_Rule
### HTTP Forwarding rule when create_http_forward is true
resource "google_compute_forwarding_rule" "http" {
  count                 = local.create_http_forward ? 1 : 0
  project               = var.project_id
  name                  = var.name
  region                = var.region
  network               = "projects/${var.network_project}/global/networks/${var.network}"
  subnetwork            = "projects/${var.network_project}/regions/${var.region}/subnetworks/${var.lb_subnet}"
  load_balancing_scheme = "INTERNAL_MANAGED"
  target                = google_compute_region_target_http_proxy.default[0].self_link
  ip_address            = var.ip_address
  ip_protocol           = "TCP"
  port_range            = "80"
  network_tier          = "PREMIUM"
  allow_global_access   = var.global_access
}

### HTTPS Forwading rule when SSL is true
resource "google_compute_forwarding_rule" "https" {
  count                 = var.ssl ? 1 : 0
  project               = var.project_id
  name                  = "${var.name}-https"
  region                = var.region
  network               = "projects/${var.network_project}/global/networks/${var.network}"
  subnetwork            = "projects/${var.network_project}/regions/${var.region}/subnetworks/${var.lb_subnet}"
  load_balancing_scheme = "INTERNAL_MANAGED"
  target                = google_compute_region_target_https_proxy.default[0].self_link
  ip_address            = var.ip_address
  ip_protocol           = "TCP"
  port_range            = "443"
  network_tier          = "PREMIUM"
  allow_global_access   = var.global_access
}

### Create Target Proxy
### HTTP proxy when http forwarding is true
resource "google_compute_region_target_http_proxy" "default" {
  count   = local.create_http_forward ? 1 : 0
  project = var.project_id
  name    = "${var.name}-http-proxy"
  region  = var.region
  url_map = var.https_redirect == false ? join("", google_compute_region_url_map.http_lb.*.self_link) : join("", google_compute_region_url_map.https_redirect.*.self_link)
}

### HTTPS proxy when SSL is true
resource "google_compute_region_target_https_proxy" "default" {
  count            = var.ssl ? 1 : 0
  project          = var.project_id
  name             = "${var.name}-https-proxy"
  region           = var.region
  url_map          = join("", google_compute_region_url_map.https_lb.*.self_link)
  ssl_certificates = var.ssl_certificates
}

resource "google_compute_region_url_map" "https_lb" {
  count   = var.ssl ? 1 : 0
  project = var.project_id
  name    = "${var.name}-https-url-map"
  region  = var.region
  ## update in the future
  default_service = local.default_service
}

resource "google_compute_region_url_map" "http_lb" {
  count   = var.http_forward ? 1 : 0
  project = var.project_id
  name    = "${var.name}-http-url-map"
  region  = var.region
  ## update in the future
  default_service = local.default_service
}

### HTTP - HTTPS Redirect
resource "google_compute_region_url_map" "https_redirect" {
  count           = var.https_redirect ? 1 : 0
  project         = var.project_id
  name            = "${var.name}-https-redirect"
  region          = var.region
  default_service = local.default_service
  host_rule {
    hosts        = [var.fqdn]
    path_matcher = "redirect"
  }
  path_matcher {
    name            = "redirect"
    default_service = local.default_service
    path_rule {
      paths = ["/*"]
      url_redirect {
        https_redirect         = true
        redirect_response_code = "PERMANENT_REDIRECT"
        strip_query            = false
      }
    }
  }
}


### Create a backend using http if health check type is http
resource "google_compute_region_backend_service" "http" {
  count                 = var.health_check["type"] == "http" ? 1 : 0
  project               = var.project_id
  name                  = "${var.name}-http-backend-service"
  region                = var.region
  protocol              = "HTTP"
  port_name             = "http-server"
  load_balancing_scheme = "INTERNAL_MANAGED"
  timeout_sec           = var.backend_timeout_sec
  session_affinity      = var.session_affinity
  locality_lb_policy    = var.session_affinity != "NONE" ? var.locality_lb_policy : null
  health_checks         = [google_compute_region_health_check.http[0].self_link]
  dynamic "backend" {
    for_each = var.backends
    content {
      balancing_mode        = lookup(backend.value, "balancing_mode", null)
      capacity_scaler       = lookup(backend.value, "capacity_scaler", null)
      group                 = lookup(backend.value, "group", null)
      description           = lookup(backend.value, "description", null)
      max_rate              = lookup(backend.value, "max_rate", null)
      max_rate_per_instance = lookup(backend.value, "max_rate_per_instance", null)
      max_rate_per_endpoint = lookup(backend.value, "max_rate_per_endpoint", null)
    }
  }
  dynamic "consistent_hash" {
    for_each = var.consistent_hash != null ? [var.consistent_hash] : []
    content {
      http_cookie {
        ttl {
          seconds = consistent_hash.value.http_cookie.ttl.seconds
          nanos   = consistent_hash.value.http_cookie.ttl.nanos
        }
        name = consistent_hash.value.http_cookie.name
        path = consistent_hash.value.http_cookie.path
      }
      http_header_name  = consistent_hash.value.http_header_name
      minimum_ring_size = consistent_hash.value.minimum_ring_size
    }
  }
}

### Create a backend using https if health check type is https
resource "google_compute_region_backend_service" "https" {
  count                 = var.health_check["type"] == "https" ? 1 : 0
  project               = var.project_id
  name                  = "${var.name}-https-backend-service"
  region                = var.region
  protocol              = "HTTPS"
  port_name             = "https-server"
  load_balancing_scheme = "INTERNAL_MANAGED"
  timeout_sec           = var.backend_timeout_sec
  session_affinity      = var.session_affinity
  locality_lb_policy    = var.session_affinity != "NONE" ? var.locality_lb_policy : null
  health_checks         = [google_compute_region_health_check.https[0].self_link]
  dynamic "backend" {
    for_each = var.backends
    content {
      balancing_mode        = lookup(backend.value, "balancing_mode", null)
      capacity_scaler       = lookup(backend.value, "capacity_scaler", null)
      group                 = lookup(backend.value, "group", null)
      description           = lookup(backend.value, "description", null)
      max_rate              = lookup(backend.value, "max_rate", null)
      max_rate_per_instance = lookup(backend.value, "max_rate_per_instance", null)
      max_rate_per_endpoint = lookup(backend.value, "max_rate_per_endpoint", null)
    }
  }
  dynamic "consistent_hash" {
    for_each = var.consistent_hash != null ? [var.consistent_hash] : []
    content {
      http_cookie {
        ttl {
          seconds = consistent_hash.value.http_cookie.ttl.seconds
          nanos   = consistent_hash.value.http_cookie.ttl.nanos
        }
        name = consistent_hash.value.http_cookie.name
        path = consistent_hash.value.http_cookie.path
      }
      http_header_name  = consistent_hash.value.http_header_name
      minimum_ring_size = consistent_hash.value.minimum_ring_size
    }
  }
}

### Create a backend using tcp if health check type is tcp
resource "google_compute_region_backend_service" "tcp" {
  count                 = var.health_check["type"] == "tcp" ? 1 : 0
  project               = var.project_id
  name                  = "${var.name}-tcp-backend-service"
  region                = var.region
  protocol              = "TCP"
  port_name             = "tcp-server"
  load_balancing_scheme = "INTERNAL_MANAGED"
  timeout_sec           = var.backend_timeout_sec
  session_affinity      = var.session_affinity
  health_checks         = [google_compute_region_health_check.tcp[0].self_link]
  dynamic "backend" {
    for_each = var.backends
    content {
      balancing_mode        = lookup(backend.value, "balancing_mode", null)
      capacity_scaler       = lookup(backend.value, "capacity_scaler", null)
      group                 = lookup(backend.value, "group", null)
      description           = lookup(backend.value, "description", null)
      max_rate              = lookup(backend.value, "max_rate", null)
      max_rate_per_instance = lookup(backend.value, "max_rate_per_instance", null)
      max_rate_per_endpoint = lookup(backend.value, "max_rate_per_endpoint", null)
    }
  }
}

### health check based on tcp, http, or https
resource "google_compute_region_health_check" "tcp" {
  provider = google-beta
  count    = var.health_check["type"] == "tcp" ? 1 : 0
  project  = var.project_id
  region   = var.region
  name     = "${var.name}-hc-tcp"

  timeout_sec         = var.health_check["timeout_sec"]
  check_interval_sec  = var.health_check["check_interval_sec"]
  healthy_threshold   = var.health_check["healthy_threshold"]
  unhealthy_threshold = var.health_check["unhealthy_threshold"]

  tcp_health_check {
    port         = var.health_check["port"]
    request      = var.health_check["request"]
    response     = var.health_check["response"]
    port_name    = var.health_check["port_name"]
    proxy_header = var.health_check["proxy_header"]
  }

  dynamic "log_config" {
    for_each = var.health_check["enable_log"] ? [true] : []
    content {
      enable = true
    }
  }
}

resource "google_compute_region_health_check" "http" {
  provider = google-beta
  count    = var.health_check["type"] == "http" ? 1 : 0
  project  = var.project_id
  region   = var.region
  name     = "${var.name}-hc-http"

  timeout_sec         = var.health_check["timeout_sec"]
  check_interval_sec  = var.health_check["check_interval_sec"]
  healthy_threshold   = var.health_check["healthy_threshold"]
  unhealthy_threshold = var.health_check["unhealthy_threshold"]

  http_health_check {
    port         = var.health_check["port"]
    request_path = var.health_check["request_path"]
    host         = var.health_check["host"]
    response     = var.health_check["response"]
    port_name    = var.health_check["port_name"]
    proxy_header = var.health_check["proxy_header"]
  }

  dynamic "log_config" {
    for_each = var.health_check["enable_log"] ? [true] : []
    content {
      enable = true
    }
  }
}

resource "google_compute_region_health_check" "https" {
  provider = google-beta
  count    = var.health_check["type"] == "https" ? 1 : 0
  project  = var.project_id
  region   = var.region
  name     = "${var.name}-hc-https"

  timeout_sec         = var.health_check["timeout_sec"]
  check_interval_sec  = var.health_check["check_interval_sec"]
  healthy_threshold   = var.health_check["healthy_threshold"]
  unhealthy_threshold = var.health_check["unhealthy_threshold"]

  https_health_check {
    port         = var.health_check["port"]
    request_path = var.health_check["request_path"]
    host         = var.health_check["host"]
    response     = var.health_check["response"]
    port_name    = var.health_check["port_name"]
    proxy_header = var.health_check["proxy_header"]
  }

  dynamic "log_config" {
    for_each = var.health_check["enable_log"] ? [true] : []
    content {
      enable = true
    }
  }
}
