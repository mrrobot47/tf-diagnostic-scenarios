terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

resource "google_compute_instance" "test_vm" {
  name         = "lb-test-vm"
  machine_type = "e2-micro"
  zone         = var.zone
  allow_stopping_for_update = true
  tags         = ["http-health-check"]

  service_account {
    scopes = ["cloud-platform"]
  }

  boot_disk {
    initialize_params {
      image = "cos-cloud/cos-stable"
    }
  }

  network_interface {
    network = "default"
  }

  metadata = {
    "gce-container-declaration" = "spec:\n  containers:\n    - name: hello-app\n      image: gcr.io/google-samples/hello-app:1.0\n      ports:\n        - containerPort: 8080\n          hostPort: 8080\n      stdin: false\n      tty: false\n  restartPolicy: Always",
    "startup-script" = "#!/bin/bash\ncurl -sS --fail https://www.google.com > /dev/null && echo 'SUCCESS: Internet access is available.' || echo 'FAILURE: No internet access.'"
  }
}

resource "google_compute_instance_group" "test_ig" {
  name      = "lb-test-ig"
  zone      = var.zone
  instances = [google_compute_instance.test_vm.id]
  named_port {
    name = "http"
    port = "8080"
  }
}

resource "google_compute_health_check" "http_check" {
  name               = "lb-test-http-health-check"
  http_health_check {
    port = "8080"
  }
}

resource "google_compute_backend_service" "backend" {
  name          = "lb-test-backend-service"
  protocol      = "HTTP"
  port_name     = "http"
  health_checks = [google_compute_health_check.http_check.id]

  backend {
    group = google_compute_instance_group.test_ig.id
  }
}

resource "google_compute_url_map" "url_map" {
  name            = "lb-test-url-map"
  default_service = google_compute_backend_service.backend.id
}

resource "google_compute_managed_ssl_certificate" "ssl_cert" {
  name    = "lb-test-ssl-cert"
  managed {
    domains = [var.domain_name]
  }
}

resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "lb-test-https-proxy"
  url_map          = google_compute_url_map.url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.ssl_cert.id]
}

resource "google_compute_global_address" "lb_ip" {
  name = "lb-test-static-ip"
}

resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name       = "lb-test-forwarding-rule"
  target     = google_compute_target_https_proxy.https_proxy.id
  ip_address = google_compute_global_address.lb_ip.address
  port_range = "443"
}

resource "google_compute_router" "router" {
  name    = "lb-test-router"
  network = "default"
  region  = "us-central1"
}

resource "google_compute_router_nat" "nat" {
  name                               = "lb-test-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  nat_ip_allocate_option             = "AUTO_ONLY"
}

resource "google_compute_firewall" "allow_health_check" {
  name    = "allow-lb-health-check-test"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["http-health-check"]
}

resource "google_compute_firewall" "allow_lb_traffic" {
  name    = "allow-lb-traffic-test"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-health-check"]
}
