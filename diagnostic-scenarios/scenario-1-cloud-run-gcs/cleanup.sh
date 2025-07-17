#!/bin/bash
echo "This script provides a fallback for a failed 'terraform destroy'."

# Load from .env if available
if [ -f "../../.env" ]; then
    export $(grep -v '^#' ../../.env | xargs)
fi

# Prompt only if not set
if [ -z "$PROJECT_ID" ]; then
    read -p "Enter your Project ID: " PROJECT_ID
fi
if [ -z "$REGION" ]; then
    read -p "Enter the Region (e.g., us-central1): " REGION
fi

SERVICE_NAME="hello-world-test-service"
BUCKET_NAME="${PROJECT_ID}-test-bucket"
SA_EMAIL="cloud-run-test-sa@${PROJECT_ID}.iam.gserviceaccount.com"

echo "--- Deleting Cloud Run Service: ${SERVICE_NAME} ---"
gcloud run services delete ${SERVICE_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet

echo "--- Deleting GCS Bucket: ${BUCKET_NAME} ---"
gsutil rm -r gs://${BUCKET_NAME}

echo "--- Deleting Service Account: ${SA_EMAIL} ---"
gcloud iam service-accounts delete ${SA_EMAIL} --project=${PROJECT_ID} --quiet

echo "Cleanup attempt finished."
