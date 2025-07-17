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
if [ -z "$ZONE" ]; then
    read -p "Enter the Zone (e.g., us-central1-a): " ZONE
fi

VM_NAME="nat-test-vm"
NAT_NAME="nat-test-gateway"
ROUTER_NAME="nat-test-router"
SUBNET_NAME="nat-test-subnet"
VPC_NAME="nat-test-network"

echo "--- Deleting Compute Instance: ${VM_NAME} ---"
gcloud compute instances delete ${VM_NAME} --zone=${ZONE} --project=${PROJECT_ID} --quiet

echo "--- Deleting Cloud NAT Gateway: ${NAT_NAME} ---"
gcloud compute routers nats delete ${NAT_NAME} --router=${ROUTER_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet

echo "--- Deleting Cloud Router: ${ROUTER_NAME} ---"
gcloud compute routers delete ${ROUTER_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet

echo "--- Deleting Subnet: ${SUBNET_NAME} ---"
gcloud compute networks subnets delete ${SUBNET_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet

echo "--- Deleting VPC Network: ${VPC_NAME} ---"
gcloud compute networks delete ${VPC_NAME} --project=${PROJECT_ID} --quiet

echo "Cleanup attempt finished."