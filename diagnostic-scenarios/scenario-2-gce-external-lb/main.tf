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

resource "google_compute_instance" "web_server_vm" {
  name         = "test-sc-2-vm"
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

resource "google_compute_instance_group" "web_server_instance_group" {
  name      = "test-sc-2-ig"
  zone      = var.zone
  instances = [google_compute_instance.web_server_vm.id]
  named_port {
    name = "http"
    port = "8080"
  }
}

resource "google_compute_health_check" "web_server_health_check" {
  name               = "test-sc-2-health-check"
  http_health_check {
    port = "8080"
  }
}

resource "google_compute_backend_service" "web_server_backend_service" {
  name          = "test-sc-2-backend-service"
  protocol      = "HTTP"
  port_name     = "http"
  health_checks = [google_compute_health_check.web_server_health_check.id]

  backend {
    group = google_compute_instance_group.web_server_instance_group.id
  }
}

resource "google_compute_url_map" "load_balancer_url_map" {
  name            = "test-sc-2-url-map"
  default_service = google_compute_backend_service.web_server_backend_service.id
}

resource "google_compute_managed_ssl_certificate" "load_balancer_ssl_certificate" {
  name    = "test-sc-2-ssl-cert"
  managed {
    domains = [var.domain_name]
  }
}

resource "google_compute_target_https_proxy" "load_balancer_https_proxy" {
  name             = "test-sc-2-https-proxy"
  url_map          = google_compute_url_map.load_balancer_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.load_balancer_ssl_certificate.id]
}

resource "google_compute_global_address" "load_balancer_static_ip" {
  name = "test-sc-2-static-ip"
}

resource "google_compute_global_forwarding_rule" "load_balancer_forwarding_rule" {
  name       = "test-sc-2-forwarding-rule"
  target     = google_compute_target_https_proxy.load_balancer_https_proxy.id
  ip_address = google_compute_global_address.load_balancer_static_ip.address
  port_range = "443"
}

resource "google_compute_router" "nat_router" {
  name    = "test-sc-2-router"
  network = "default"
  region  = var.region
}

resource "google_compute_router_nat" "vm_nat_gateway" {
  name                               = "test-sc-2-nat"
  router                             = google_compute_router.nat_router.name
  region                             = google_compute_router.nat_router.region
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
  nat_ip_allocate_option             = "AUTO_ONLY"
}

resource "google_compute_firewall" "allow_health_check" {
  name    = "test-sc-2-allow-health-check"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["http-health-check"]
}

resource "google_compute_firewall" "allow_lb_traffic" {
  name    = "test-sc-2-allow-lb-traffic"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-health-check"]
}
