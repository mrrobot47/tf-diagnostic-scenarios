#!/bin/bash
set -e

if [ -z "$PROJECT_ID" ]; then
    read -p "Enter your Project ID: " PROJECT_ID
fi
if [ -z "$REGION" ]; then
    read -p "Enter the Region (e.g., us-central1): " REGION
fi

echo "--- Starting Cleanup for Scenario 10 ---"

# Cloud Run
gcloud run services delete test-sc-10-full-state-tester --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Cloud Run service not found."

# GCS Bucket
BUCKET_NAME="test-sc-10-bucket-${PROJECT_ID}"
gsutil -m rm -r "gs://${BUCKET_NAME}" || echo "GCS bucket not found."

# Cloud SQL
gcloud sql instances delete test-sc-10-postgres-db --project=${PROJECT_ID} --quiet || echo "Cloud SQL instance not found."

# Redis
gcloud redis instances delete test-sc-10-redis-cache --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Redis instance not found."

# Service Account
SA_EMAIL="test-sc-10-run-sa@${PROJECT_ID}.iam.gserviceaccount.com"
gcloud iam service-accounts delete ${SA_EMAIL} --project=${PROJECT_ID} --quiet || echo "Service account not found."

# VPC Peering for Private Services
gcloud services vpc-peerings delete --service=servicenetworking.googleapis.com --network=test-sc-10-vpc --project=${PROJECT_ID} --quiet || echo "VPC peering not found."

# Private Service Access IP Range
gcloud compute addresses delete test-sc-10-private-access --global --project=${PROJECT_ID} --quiet || echo "Private service access address not found."

# Subnet and VPC
gcloud compute networks subnets delete test-sc-10-subnet --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Subnet not found."
gcloud compute networks delete test-sc-10-vpc --project=${PROJECT_ID} --quiet || echo "VPC not found."

echo "--- Cleanup for Scenario 10 Finished ---"
