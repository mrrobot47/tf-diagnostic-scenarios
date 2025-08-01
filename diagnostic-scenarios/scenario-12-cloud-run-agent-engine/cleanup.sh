#!/bin/bash
# Cleanup script for scenario-12-cloud-run-agent-engine
# Provides a fallback for failed 'terraform destroy' or manual cleanup

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
if [ -z "$TEST_USER_EMAIL" ]; then
    read -p "Enter the test user email: " TEST_USER_EMAIL
fi

SERVICE_NAME="test-sc-12-tester"
SA_EMAIL="test-sc-12-sa@${PROJECT_ID}.iam.gserviceaccount.com"
VPC_NAME="test-sc-12-vpc"
SUBNET_NAME="test-sc-12-subnet"
ROUTER_NAME="test-sc-12-router"
NAT_NAME="test-sc-12-nat"

# Delete Cloud Run service
echo "--- Deleting Cloud Run Service: ${SERVICE_NAME} ---"
gcloud run services delete ${SERVICE_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet

# Delete Service Account
echo "--- Deleting Service Account: ${SA_EMAIL} ---"
gcloud iam service-accounts delete ${SA_EMAIL} --project=${PROJECT_ID} --quiet

# Delete NAT
echo "--- Deleting Cloud NAT: ${NAT_NAME} ---"
gcloud compute routers nats delete ${NAT_NAME} --router=${ROUTER_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet

# Delete Router
echo "--- Deleting Router: ${ROUTER_NAME} ---"
gcloud compute routers delete ${ROUTER_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet

# Delete Subnet
echo "--- Deleting Subnet: ${SUBNET_NAME} ---"
gcloud compute networks subnets delete ${SUBNET_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet

# Delete VPC
echo "--- Deleting VPC: ${VPC_NAME} ---"
gcloud compute networks delete ${VPC_NAME} --project=${PROJECT_ID} --quiet

echo "Cleanup attempt finished."
