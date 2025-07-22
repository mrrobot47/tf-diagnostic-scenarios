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

echo "-----------------------------------------------------"
echo "Starting Cleanup for Scenario 7..."
echo "Project: $PROJECT_ID"
echo "Region:  $REGION"
echo "-----------------------------------------------------"

SERVICE_NAME="test-sc-7-vector-search-connect"
SA_EMAIL="test-sc-7-sa@${PROJECT_ID}.iam.gserviceaccount.com"
ENDPOINT_DISPLAY_NAME="test-sc-7-endpoint"
INDEX_DISPLAY_NAME="test-sc-7-index"
SUBNET_NAME="test-sc-7-subnet"
VPC_NAME="test-sc-7-network"
ROUTER_NAME="test-sc-7-router"
NAT_NAME="test-sc-7-nat"

echo "--- Deleting Cloud Run Service: ${SERVICE_NAME} ---"
gcloud run services delete ${SERVICE_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Service not found or already deleted."

echo "--- Removing IAM binding for Service Account ---"
gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/aiplatform.user" --quiet || echo "IAM binding not found."

echo "--- Deleting Service Account: ${SA_EMAIL} ---"
gcloud iam service-accounts delete ${SA_EMAIL} --project=${PROJECT_ID} --quiet || echo "Service Account not found or already deleted."

echo "--- Deleting Vertex AI Index Endpoint ---"
ENDPOINT_ID=$(gcloud ai index-endpoints list --region=${REGION} --project=${PROJECT_ID} --filter="displayName=${ENDPOINT_DISPLAY_NAME}" --format="value(name)")
if [[ -n "$ENDPOINT_ID" ]]; then
    # Undeploy all indexes first
    DEPLOYED_INDEXES=$(gcloud ai index-endpoints describe ${ENDPOINT_ID} --region=${REGION} --project=${PROJECT_ID} --format="json(deployedIndexes)" | grep "id" | awk -F'"' '{print $4}')
    for DEPLOYED_INDEX in $DEPLOYED_INDEXES; do
        echo "Undeploying index ${DEPLOYED_INDEX}..."
        gcloud ai index-endpoints undeploy-index ${ENDPOINT_ID} --deployed-index-id=${DEPLOYED_INDEX} --region=${REGION} --project=${PROJECT_ID} --quiet
    done
    gcloud ai index-endpoints delete ${ENDPOINT_ID} --region=${REGION} --project=${PROJECT_ID} --quiet
else
    echo "Endpoint not found or already deleted."
fi

echo "--- Deleting Vertex AI Index ---"
INDEX_ID=$(gcloud ai indexes list --region=${REGION} --project=${PROJECT_ID} --filter="displayName=${INDEX_DISPLAY_NAME}" --format="value(name)")
if [[ -n "$INDEX_ID" ]]; then
    gcloud ai indexes delete ${INDEX_ID} --region=${REGION} --project=${PROJECT_ID} --quiet
else
    echo "Index not found or already deleted."
fi

echo "--- Deleting Cloud NAT Gateway: ${NAT_NAME} ---"
gcloud compute routers nats delete ${NAT_NAME} --router=${ROUTER_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet || echo "NAT Gateway not found or already deleted."

echo "--- Deleting Cloud Router: ${ROUTER_NAME} ---"
gcloud compute routers delete ${ROUTER_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Cloud Router not found or already deleted."

echo "--- Deleting Subnet: ${SUBNET_NAME} ---"
gcloud compute networks subnets delete ${SUBNET_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Subnet not found or already deleted."

echo "--- Deleting VPC Network: ${VPC_NAME} ---"
gcloud compute networks delete ${VPC_NAME} --project=${PROJECT_ID} --quiet || echo "VPC not found or already deleted."

echo "Cleanup attempt finished."