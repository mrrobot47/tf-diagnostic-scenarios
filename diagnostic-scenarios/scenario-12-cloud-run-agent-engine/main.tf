terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.31.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

# 1. Enable necessary APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "iam.googleapis.com",
    "compute.googleapis.com",
    "aiplatform.googleapis.com",
    "servicenetworking.googleapis.com"
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# 2. Create the VPC and Subnet (optional, can use default network if preferred)
resource "google_compute_network" "vpc" {
  name                    = "test-sc-12-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "subnet" {
  name          = "test-sc-12-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# 3. Add Cloud NAT for outbound internet access
resource "google_compute_router" "router" {
  name    = "test-sc-12-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name   = "test-sc-12-nat"
  router = google_compute_router.router.name
  region = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# 4. Create the dedicated Service Account for Cloud Run
resource "google_service_account" "reasoning_engine_sa" {
  account_id   = "test-sc-12-sa"
  display_name = "Test SC 12 Cloud Run SA"
  depends_on   = [google_project_service.apis]
}

# 5. Grant the required IAM permissions for Vertex AI
resource "google_project_iam_member" "aiplatform_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.reasoning_engine_sa.email}"
}

resource "google_project_iam_member" "vertex_ai_user" {
  project = var.project_id
  role    = "roles/ml.developer"
  member  = "serviceAccount:${google_service_account.reasoning_engine_sa.email}"
}

# 6. Deploy the Cloud Run test service
resource "google_cloud_run_v2_service" "reasoning_engine_tester" {
  name                = "test-sc-12-tester"
  location            = var.region
  deletion_protection = false

  template {
    service_account = google_service_account.reasoning_engine_sa.email

    # Increase timeouts and limits
    timeout = "3600s"  # 1 hour timeout

    scaling {
      max_instance_count = 1
    }

    # Direct VPC Egress configuration (like your working example)
    vpc_access {
      network_interfaces {
        network    = google_compute_network.vpc.id
        subnetwork = google_compute_subnetwork.subnet.id
        tags       = ["test-sc-12"]
      }
      egress = "ALL_TRAFFIC"
    }

    containers {
      image = "python:3.11-slim"
      command = ["/bin/bash", "-c"]

      # Increase memory and CPU limits
      resources {
        limits = {
          memory = "2Gi"
          cpu    = "2000m"
        }
      }

      # Configure startup and liveness probes with valid limits
      startup_probe {
        http_get {
          path = "/"
          port = 8080
        }
        initial_delay_seconds = 60   # 1 minute (max is 240)
        timeout_seconds = 30
        period_seconds = 30
        failure_threshold = 10       # 10 failures * 30s = 5 minutes total
      }

      liveness_probe {
        http_get {
          path = "/"
          port = 8080
        }
        initial_delay_seconds = 240  # 4 minutes (max allowed)
        timeout_seconds = 30
        period_seconds = 60
        failure_threshold = 10       # Allow up to 10 minutes of unresponsiveness
      }
      args = [
        <<-EOT
          echo "=== Starting HTTP server FIRST to handle health checks ==="
          # Start a background HTTP server immediately to respond to health checks
          python -c "
import http.server
import socketserver
import threading
import time
import os

class InstallationHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        # Check if installation is complete
        if os.path.exists('/tmp/installation_complete'):
            self.wfile.write(b'<h1>Installation Complete - Starting Tests...</h1>')
        else:
            self.wfile.write(b'<h1>Installing packages, please wait...</h1><p>This may take 5-10 minutes.</p>')

def start_server():
    with socketserver.TCPServer(('', 8080), InstallationHandler) as httpd:
        httpd.serve_forever()

# Start server in background thread
server_thread = threading.Thread(target=start_server, daemon=True)
server_thread.start()
print('Health server started on port 8080')
" &
          echo "=== Waiting for server to start ==="
          sleep 10
          echo "=== Installing gcloud CLI ==="
          apt-get update -q
          apt-get install -y -q curl jq apt-transport-https ca-certificates gnupg
          curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
          echo "deb https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
          apt-get update -q
          apt-get install -y -q google-cloud-cli
          echo "=== Installing Python packages (this will take several minutes) ==="
          pip install --upgrade pip --quiet
          echo "Starting google-cloud-aiplatform installation at $(date)"
          pip install google-cloud-aiplatform --quiet
          echo "Completed google-cloud-aiplatform installation at $(date)"
          echo "Starting vertexai installation at $(date)"
          pip install vertexai --quiet
          echo "Completed vertexai installation at $(date)"
          echo "=== Testing imports ==="
          python -c "import google.cloud.aiplatform; print('google.cloud.aiplatform imported successfully')" || echo "FAILED: google.cloud.aiplatform not found"
          python -c "import vertexai; print('vertexai imported successfully')" || echo "FAILED: vertexai not found"
          # Mark installation as complete
          touch /tmp/installation_complete
          echo "=== Installation complete at $(date) ==="
          echo "--- Starting Reasoning Engine Tests ---"
          # Test 1: List available reasoning engines
          echo "=== Test 1: Listing Reasoning Engines ==="
          python -c "
import vertexai
from vertexai.preview import reasoning_engines
import os
import json
PROJECT_ID = os.environ.get('PROJECT_ID')
REGION = os.environ.get('REGION')
print(f'Using Project ID: {PROJECT_ID}')
print(f'Using Region: {REGION}')
try:
    vertexai.init(project=PROJECT_ID, location=REGION)
    reasoning_engine_list = reasoning_engines.ReasoningEngine.list()
    print(f'Found {len(reasoning_engine_list)} reasoning engines:')
    engines_info = []
    for engine in reasoning_engine_list:
        engine_info = {
            'resource_name': engine.resource_name,
            'display_name': getattr(engine, 'display_name', 'N/A'),
            'create_time': str(getattr(engine, 'create_time', 'N/A'))
        }
        engines_info.append(engine_info)
        print(f'  - {engine.resource_name}')
    # Save engines info for the web interface
    with open('/tmp/engines.json', 'w') as f:
        json.dump(engines_info, f, indent=2)
    # Extract first engine ID for testing
    if reasoning_engine_list:
        first_engine = reasoning_engine_list[0]
        engine_id = first_engine.resource_name.split('/')[-1]
        with open('/tmp/engine_id.txt', 'w') as f:
            f.write(engine_id)
        print(f'First engine ID: {engine_id}')
    else:
        print('No reasoning engines found!')
        with open('/tmp/engine_id.txt', 'w') as f:
            f.write('NONE')
except Exception as e:
    print(f'Error listing engines: {str(e)}')
    import traceback
    traceback.print_exc()
    with open('/tmp/engines.json', 'w') as f:
        json.dump([{'error': str(e)}], f)
    with open('/tmp/engine_id.txt', 'w') as f:
        f.write('ERROR')
"
          # Test 2: Test curl request to reasoning engine (if available)
          echo "=== Test 2: Testing Reasoning Engine Query ==="
          ENGINE_ID=$(cat /tmp/engine_id.txt)
          if [ "$ENGINE_ID" != "NONE" ] && [ "$ENGINE_ID" != "ERROR" ]; then
            echo "Testing engine ID: $ENGINE_ID"
            # Get access token
            ACCESS_TOKEN=$(gcloud auth print-access-token)
            # Make curl request with proper JSON structure
            CURL_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%%{http_code}" \
              -H "Authorization: Bearer $ACCESS_TOKEN" \
              -H "Content-Type: application/json" \
              "https://$REGION-aiplatform.googleapis.com/v1/projects/$PROJECT_ID/locations/$REGION/reasoningEngines/$ENGINE_ID:streamQuery?alt=sse" \
              -d '{
                "class_method": "stream_query",
                "input": {
                  "message": "Hello, this is a test from Cloud Run!",
                  "user_id": "test_user"
                }
              }' 2>&1)
            echo "Curl response:"
            echo "$CURL_RESPONSE"
            echo "$CURL_RESPONSE" > /tmp/curl_response.txt
          else
            echo "No valid engine ID available for testing"
            echo "No engine available" > /tmp/curl_response.txt
          fi
          echo "--- Starting Web Server ---"
          python -c "
import http.server, socketserver, os, json, datetime
class ReasoningEngineTestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html; charset=utf-8')
        self.end_headers()
        # Get environment variables
        project_id = os.environ.get('PROJECT_ID', 'N/A')
        region = os.environ.get('REGION', 'N/A')
        service_account_email = os.environ.get('SERVICE_ACCOUNT_EMAIL', 'N/A')
        # Read test results
        try:
            with open('/tmp/engines.json', 'r') as f:
                engines_data = json.load(f)
        except:
            engines_data = [{'error': 'Failed to load engines data'}]
        try:
            with open('/tmp/engine_id.txt', 'r') as f:
                engine_id = f.read().strip()
        except:
            engine_id = 'ERROR'
        try:
            with open('/tmp/curl_response.txt', 'r') as f:
                curl_response = f.read().strip()
        except:
            curl_response = 'No response available'
        # Determine status
        list_status = '✅ SUCCESS' if not any('error' in str(engine) for engine in engines_data) else '❌ FAILURE'
        curl_status = '✅ SUCCESS' if ('"content"' in curl_response or '"text"' in curl_response) else '❌ FAILURE' if engine_id not in ['NONE', 'ERROR'] else '⚪ SKIPPED'
        engines_table = ''
        for i, engine in enumerate(engines_data):
            if 'error' in engine:
                engines_table += f'<tr><td>Error</td><td colspan=\"2\">{engine[\"error\"]}</td></tr>'
            else:
                engines_table += f'''
                <tr>
                    <td>{i+1}</td>
                    <td>{engine.get(\"resource_name\", \"N/A\").split(\"/\")[-1]}</td>
                    <td>{engine.get(\"display_name\", \"N/A\")}</td>
                </tr>'''
        html = f'''<!DOCTYPE html>
<html>
<head>
    <meta charset=\"utf-8\">
    <title>Reasoning Engine Test Results</title>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 40px; background: #f8f9fa; }}
        .container {{ max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }}
        h1 {{ color: #1a73e8; margin-bottom: 30px; display: flex; align-items: center; gap: 10px; }}
        .status-card {{ background: #f8f9fa; border-radius: 8px; padding: 20px; margin: 20px 0; border-left: 4px solid #1a73e8; }}
        table {{ border-collapse: collapse; width: 100%; margin: 20px 0; }}
        td, th {{ border: 1px solid #e0e0e0; padding: 12px; text-align: left; }}
        th {{ background: #f1f3f4; font-weight: 600; }}
        .success {{ color: #137333; font-weight: 600; }}
        .failure {{ color: #d93025; font-weight: 600; }}
        .skipped {{ color: #5f6368; font-weight: 600; }}
        .response-box {{ background: #f8f9fa; border: 1px solid #e0e0e0; border-radius: 8px; padding: 15px; margin: 15px 0; font-family: 'Courier New', monospace; font-size: 12px; white-space: pre-wrap; max-height: 300px; overflow-y: auto; }}
        .info {{ background: #e8f0fe; border-radius: 8px; padding: 20px; margin: 20px 0; }}
        .timestamp {{ color: #5f6368; font-size: 14px; }}
    </style>
</head>
<body>
    <div class=\"container\">
        <h1>🤖 Reasoning Engine Test Results</h1>
        <div class=\"timestamp\">Test executed: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}</div>
        <div class=\"status-card\">
            <h3>📊 Test Summary</h3>
            <table>
                <tr>
                    <th>Test</th>
                    <th>Status</th>
                    <th>Details</th>
                </tr>
                <tr>
                    <td>List Reasoning Engines</td>
                    <td class=\"{'success' if '✅' in list_status else 'failure'}\">{list_status}</td>
                    <td>Found {len([e for e in engines_data if 'error' not in e])} engines</td>
                </tr>
                <tr>
                    <td>Query Reasoning Engine</td>
                    <td class=\"{'success' if '✅' in curl_status else 'failure' if '❌' in curl_status else 'skipped'}\">{curl_status}</td>
                    <td>Engine ID: {engine_id}</td>
                </tr>
            </table>
        </div>
        <div class=\"status-card\">
            <h3>🔍 Available Reasoning Engines</h3>
            <table>
                <tr>
                    <th>#</th>
                    <th>Engine ID</th>
                    <th>Display Name</th>
                </tr>
                {engines_table}
            </table>
        </div>
        <div class=\"status-card\">
            <h3>📡 API Response</h3>
            <div class=\"response-box\">{curl_response}</div>
        </div>
        <div class=\"info\">
            <h4>🔧 Test Configuration</h4>
            <strong>Project:</strong> {project_id}<br>
            <strong>Region:</strong> {region}<br>
            <strong>Service Account:</strong> {service_account_email}<br>
            <strong>API Endpoint:</strong> https://{region}-aiplatform.googleapis.com/v1/<br><br>
            <h4>🧪 Tests Performed</h4>
            1. <strong>Python SDK Test:</strong> Uses vertexai library to list reasoning engines<br>
            2. <strong>REST API Test:</strong> Direct curl request to streamQuery endpoint<br>
            3. <strong>Authentication Test:</strong> Verifies service account permissions<br>
        </div>
    </div>
</body>
</html>'''
        self.wfile.write(html.encode('utf-8'))
print('Starting HTTP server on port 8080...')
with socketserver.TCPServer(('', 8080), ReasoningEngineTestHandler) as httpd:
    httpd.serve_forever()
"
        EOT
      ]
      env {
        name  = "PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "REGION"
        value = var.region
      }
      env {
        name  = "SERVICE_ACCOUNT_EMAIL"
        value = google_service_account.reasoning_engine_sa.email
      }
      ports { 
        container_port = 8080 
      }
    }
  }
  depends_on = [
    google_project_iam_member.aiplatform_user,
    google_project_iam_member.vertex_ai_user,
    google_compute_router_nat.nat
  ]
}

# 7. Allow the specified test user to invoke the service
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  project  = google_cloud_run_v2_service.reasoning_engine_tester.project
  location = google_cloud_run_v2_service.reasoning_engine_tester.location
  name     = google_cloud_run_v2_service.reasoning_engine_tester.name
  role     = "roles/run.invoker"
  member   = "user:${var.test_user_email}"
}
