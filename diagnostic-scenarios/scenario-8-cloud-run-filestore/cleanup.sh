#!/bin/bash
set -e

# Load from .env if available
if [ -f "../../.env" ]; then
    export $(grep -v '^#' ../../.env | xargs)
fi

# Fallback to prompting if variables are not set
if [ -z "$PROJECT_ID" ]; then
    read -p "Enter your Project ID: " PROJECT_ID
fi

if [ -z "$REGION" ]; then
    read -p "Enter the Region (e.g., us-central1): " REGION
fi

if [ -z "$ZONE" ]; then
    read -p "Enter the Zone (e.g., us-central1-a): " ZONE
fi


echo "-----------------------------------------------------"
echo "Starting Cleanup for Scenario 8..."
echo "Project: $PROJECT_ID"
echo "Region:  $REGION"
echo "Zone:    $ZONE"
echo "-----------------------------------------------------"

SERVICE_NAME="test-sc-8-filestore-mount"
FILESTORE_INSTANCE_NAME="test-sc-8-nfs"
SA_EMAIL="test-sc-8-sa@${PROJECT_ID}.iam.gserviceaccount.com"
SUBNET_NAME="test-sc-8-subnet"
VPC_NAME="test-sc-8-network"

echo "--- Deleting Cloud Run Service: ${SERVICE_NAME} ---"
gcloud run services delete ${SERVICE_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Service not found or already deleted."

echo "--- Deleting Filestore Instance: ${FILESTORE_INSTANCE_NAME} ---"
gcloud filestore instances delete ${FILESTORE_INSTANCE_NAME} --location=${ZONE} --project=${PROJECT_ID} --quiet || echo "Filestore Instance not found or already deleted."

echo "--- Deleting Service Account: ${SA_EMAIL} ---"
gcloud iam service-accounts delete ${SA_EMAIL} --project=${PROJECT_ID} --quiet || echo "Service Account not found or already deleted."

echo "--- Deleting Subnet: ${SUBNET_NAME} ---"
gcloud compute networks subnets delete ${SUBNET_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Subnet not found or already deleted."

echo "--- Deleting VPC Network: ${VPC_NAME} ---"
gcloud compute networks delete ${VPC_NAME} --project=${PROJECT_ID} --quiet || echo "VPC not found or already deleted."

echo "Cleanup attempt finished."