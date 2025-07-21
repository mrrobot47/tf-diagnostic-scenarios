#!/bin/bash
set -e

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    export $(cat .env | grep -v '#' | awk '/=/ {print $1}')
fi

# Fallback to prompting if variables are not set
if [ -z "$PROJECT_ID" ]; then
    read -p "Enter your Project ID: " PROJECT_ID
fi

if [ -z "$REGION" ]; then
    read -p "Enter the Region (e.g., us-central1): " REGION
fi

echo "-----------------------------------------------------"
echo "Starting Cleanup for Scenario 5..."
echo "Project: $PROJECT_ID"
echo "Region:  $REGION"
echo "-----------------------------------------------------"

SERVICE_NAME="test-sc-5-sql-direct-connect"
DB_INSTANCE_NAME="test-sc-5-db"
SA_EMAIL="test-sc-5-sa@${PROJECT_ID}.iam.gserviceaccount.com"
# NOTE: The VPC Connector is no longer part of this cleanup
SUBNET_NAME="test-sc-5-subnet"
VPC_NAME="test-sc-5-network"
PRIVATE_IP_NAME="test-sc-5-private-ip"

echo "--- Deleting Cloud Run Service: ${SERVICE_NAME} ---"
gcloud run services delete ${SERVICE_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Service not found or already deleted."

echo "--- Deleting Cloud SQL Instance: ${DB_INSTANCE_NAME} ---"
gcloud sql instances delete ${DB_INSTANCE_NAME} --project=${PROJECT_ID} --quiet || echo "SQL Instance not found or already deleted."

echo "--- Removing IAM binding for Service Account ---"
gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/cloudsql.client" --quiet || echo "IAM binding not found."

echo "--- Deleting Service Account: ${SA_EMAIL} ---"
gcloud iam service-accounts delete ${SA_EMAIL} --project=${PROJECT_ID} --quiet || echo "Service Account not found or already deleted."

echo "--- Deleting Subnet: ${SUBNET_NAME} ---"
gcloud compute networks subnets delete ${SUBNET_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Subnet not found or already deleted."

echo "--- Deleting Private Service IP Range: ${PRIVATE_IP_NAME} ---"
gcloud compute addresses delete ${PRIVATE_IP_NAME} --global --project=${PROJECT_ID} --quiet || echo "Private IP range not found or already deleted."

echo "--- Deleting VPC Network: ${VPC_NAME} ---"
gcloud compute networks delete ${VPC_NAME} --project=${PROJECT_ID} --quiet || echo "VPC not found or already deleted."

echo "--- Deleting Cloud NAT: test-sc-5-nat ---"
gcloud compute routers nats delete test-sc-5-nat --router=test-sc-5-router --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Cloud NAT not found or already deleted."

echo "--- Deleting Cloud Router: test-sc-5-router ---"
gcloud compute routers delete test-sc-5-router --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Cloud Router not found or already deleted."

echo "--- Deleting Service Networking VPC Connection ---"
gcloud compute networks peerings delete servicenetworking-googleapis-com --network=${VPC_NAME} --project=${PROJECT_ID} --quiet || echo "VPC peering not found or already deleted."

echo "--- Disabling APIs enabled for Scenario 5 ---"
for api in run.googleapis.com sqladmin.googleapis.com compute.googleapis.com servicenetworking.googleapis.com; do
    gcloud services disable $api --project=${PROJECT_ID} --quiet || echo "$api not disabled or already disabled."
done

echo "Cleanup attempt finished."
