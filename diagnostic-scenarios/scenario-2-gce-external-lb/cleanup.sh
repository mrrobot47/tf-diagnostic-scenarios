#!/bin/bash
echo "This script provides a fallback for a failed 'terraform destroy'."
echo "Please enter the required values."

read -p "Enter your Project ID: " PROJECT_ID
read -p "Enter the Zone (e.g., us-central1-a): " ZONE

echo "--- Deleting Forwarding Rule ---"
gcloud compute forwarding-rules delete lb-test-forwarding-rule --global --project=${PROJECT_ID} --quiet
echo "--- Deleting Target HTTPS Proxy ---"
gcloud compute target-https-proxies delete lb-test-https-proxy --global --project=${PROJECT_ID} --quiet
echo "--- Deleting URL Map ---"
gcloud compute url-maps delete lb-test-url-map --global --project=${PROJECT_ID} --quiet
echo "--- Deleting SSL Certificate ---"
gcloud compute ssl-certificates delete lb-test-ssl-cert --global --project=${PROJECT_ID} --quiet
echo "--- Deleting Backend Service ---"
gcloud compute backend-services delete lb-test-backend-service --global --project=${PROJECT_ID} --quiet
echo "--- Deleting Health Check ---"
gcloud compute health-checks delete lb-test-http-health-check --global --project=${PROJECT_ID} --quiet
echo "--- Deleting Instance Group ---"
gcloud compute instance-groups unmanaged delete lb-test-ig --zone=${ZONE} --project=${PROJECT_ID} --quiet
echo "--- Deleting Compute Instance ---"
gcloud compute instances delete lb-test-vm --zone=${ZONE} --project=${PROJECT_ID} --quiet
echo "--- Deleting Static IP ---"
gcloud compute addresses delete lb-test-static-ip --global --project=${PROJECT_ID} --quiet
echo "--- Deleting Firewall Rule ---"
gcloud compute firewall-rules delete allow-lb-health-check-test --project=${PROJECT_ID} --quiet

echo "Cleanup attempt finished."
