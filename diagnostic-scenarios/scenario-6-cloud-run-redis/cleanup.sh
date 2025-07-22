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
echo "Starting Cleanup for Scenario 6..."
echo "Project: $PROJECT_ID"
echo "Region:  $REGION"
echo "-----------------------------------------------------"

SERVICE_NAME="test-sc-6-redis-direct-connect"
REDIS_INSTANCE_NAME="test-sc-6-redis"
SA_EMAIL="test-sc-6-sa@${PROJECT_ID}.iam.gserviceaccount.com"
SUBNET_NAME="test-sc-6-subnet"
VPC_NAME="test-sc-6-network"
PRIVATE_IP_NAME="test-sc-6-private-ip"
ROUTER_NAME="test-sc-6-router"
NAT_NAME="test-sc-6-nat"

# First, delete the services that use the network
echo "--- Deleting Cloud Run Service: ${SERVICE_NAME} ---"
gcloud run services delete ${SERVICE_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Service not found or already deleted."

echo "--- Deleting Redis Instance: ${REDIS_INSTANCE_NAME} ---"
gcloud redis instances delete ${REDIS_INSTANCE_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Redis Instance not found or already deleted."

# Now, remove the networking components
echo "--- Deleting Cloud NAT Gateway: ${NAT_NAME} ---"
gcloud compute routers nats delete ${NAT_NAME} --router=${ROUTER_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet || echo "NAT Gateway not found or already deleted."

echo "--- Deleting Cloud Router: ${ROUTER_NAME} ---"
gcloud compute routers delete ${ROUTER_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Cloud Router not found or already deleted."

echo "--- Deleting Subnet: ${SUBNET_NAME} ---"
gcloud compute networks subnets delete ${SUBNET_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Subnet not found or already deleted."

echo "--- Deleting Private Service IP Range: ${PRIVATE_IP_NAME} ---"
gcloud compute addresses delete ${PRIVATE_IP_NAME} --global --project=${PROJECT_ID} --quiet || echo "Private IP range not found or already deleted."

echo "--- Deleting VPC Network: ${VPC_NAME} ---"
gcloud compute networks delete ${VPC_NAME} --project=${PROJECT_ID} --quiet || echo "VPC not found or already deleted."

# Finally, clean up the IAM resources
echo "--- Removing IAM binding for Service Account ---"
gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="roles/redis.viewer" --quiet || echo "IAM binding not found."

echo "--- Deleting Service Account: ${SA_EMAIL} ---"
gcloud iam service-accounts delete ${SA_EMAIL} --project=${PROJECT_ID} --quiet || echo "Service Account not found or already deleted."

echo "Cleanup attempt finished."