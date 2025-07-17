#!/bin/bash
echo "This script provides a fallback for a failed 'terraform destroy'."
echo "Please enter the required values."

read -p "Enter your Project ID: " PROJECT_ID
read -p "Enter the Region (e.g., us-central1): " REGION

CONNECTOR_NAME="vpc-connector-test"
SUBNET_NAME="vpc-connector-test-subnet"
VPC_NAME="vpc-connector-test-network"

echo "--- Deleting VPC Connector: ${CONNECTOR_NAME} ---"
gcloud compute networks vpc-access connectors delete ${CONNECTOR_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet

echo "--- Deleting Subnet: ${SUBNET_NAME} ---"
gcloud compute networks subnets delete ${SUBNET_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet

echo "--- Deleting VPC Network: ${VPC_NAME} ---"
gcloud compute networks delete ${VPC_NAME} --project=${PROJECT_ID} --quiet

echo "Cleanup attempt finished."
