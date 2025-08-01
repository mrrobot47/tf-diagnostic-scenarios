#!/bin/bash
set -e

# Load from .env if available
if [ -f "../../.env" ]; then
    export $(grep -v '^#' ../../.env | xargs)
fi
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
fi

echo "This script provides a fallback for a failed 'terraform destroy'."
echo "Please enter the required values (will use environment variables if set)."

if [ -z "$PROJECT_ID" ]; then
    read -p "Enter your Project ID: " PROJECT_ID
fi
if [ -z "$REGION" ]; then
    read -p "Enter the Region (e.g., us-central1): " REGION
fi
if [ -z "$TEST_USER_EMAIL" ]; then
    read -p "Enter the test user email (e.g., your-email@example.com): " TEST_USER_EMAIL
fi
if [ -z "$GITHUB_BRANCH" ]; then
    read -p "Enter the GitHub branch name (e.g., main): " GITHUB_BRANCH
fi
if [ -z "$GITHUB_REPO_OWNER" ]; then
    read -p "Enter the GitHub repo owner: " GITHUB_REPO_OWNER
fi
if [ -z "$GITHUB_REPO_NAME" ]; then
    read -p "Enter the GitHub repo name: " GITHUB_REPO_NAME
fi

SERVICE_NAME="test-sc-11-open-webui"
ARTIFACT_REPO="test-sc-11-open-webui-images"
SQL_INSTANCE="test-sc-11-postgres-db"
REDIS_INSTANCE="test-sc-11-redis-instance"
BUCKET_NAME="test-sc-11-storage-bucket-${PROJECT_ID}"
VPC_NAME="test-sc-11-vpc"
SUBNET_NAME="test-sc-11-subnet"
PRIVATE_ACCESS_NAME="test-sc-11-private-access"
ROUTER_NAME="test-sc-11-router"
NAT_NAME="test-sc-11-nat"
CLOUDRUN_SA="test-sc-11-cloudrun-sa@${PROJECT_ID}.iam.gserviceaccount.com"
CLOUDBUILD_SA="test-sc-11-cloudbuild-sa@${PROJECT_ID}.iam.gserviceaccount.com"
SECRET_DB="test-sc-11-database-url"
SECRET_REDIS="test-sc-11-redis-url"
SECRET_WEBUI="test-sc-11-webui-secret-key"
TRIGGER_NAME="test-sc-11-open-webui-trigger"
IAP_MEMBER="user:${TEST_USER_EMAIL}"

# Delete Cloud Run service
 echo "--- Deleting Cloud Run Service: ${SERVICE_NAME} ---"
gcloud run services delete ${SERVICE_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Cloud Run service not found."

echo "--- Deleting Cloud Build Trigger: ${TRIGGER_NAME} ---"
TRIGGER_ID=$(gcloud builds triggers list --project=${PROJECT_ID} --filter="name:${TRIGGER_NAME}" --format="value(id)" --limit=1)
if [ -n "$TRIGGER_ID" ]; then
    gcloud builds triggers delete $TRIGGER_ID --project=${PROJECT_ID} --quiet || echo "Cloud Build trigger not found."
else
    echo "Cloud Build trigger not found."
fi

echo "--- Deleting Artifact Registry Repository: ${ARTIFACT_REPO} ---"
gcloud artifacts repositories delete ${ARTIFACT_REPO} --location=${REGION} --project=${PROJECT_ID} --quiet || echo "Artifact Registry repo not found."

echo "--- Deleting GCS Bucket: ${BUCKET_NAME} ---"
gsutil -m rm -r "gs://${BUCKET_NAME}" || echo "GCS bucket not found."

echo "--- Deleting Cloud SQL Instance: ${SQL_INSTANCE} ---"
gcloud sql instances delete ${SQL_INSTANCE} --project=${PROJECT_ID} --quiet || echo "Cloud SQL instance not found."

echo "--- Deleting Redis Instance: ${REDIS_INSTANCE} ---"
gcloud redis instances delete ${REDIS_INSTANCE} --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Redis instance not found."

echo "--- Deleting Service Accounts ---"
gcloud iam service-accounts delete ${CLOUDRUN_SA} --project=${PROJECT_ID} --quiet || echo "Cloud Run service account not found."
gcloud iam service-accounts delete ${CLOUDBUILD_SA} --project=${PROJECT_ID} --quiet || echo "Cloud Build service account not found."

echo "--- Deleting Secret Manager Secrets ---"
gcloud secrets delete ${SECRET_DB} --project=${PROJECT_ID} --quiet || echo "Secret ${SECRET_DB} not found."
gcloud secrets delete ${SECRET_REDIS} --project=${PROJECT_ID} --quiet || echo "Secret ${SECRET_REDIS} not found."
gcloud secrets delete ${SECRET_WEBUI} --project=${PROJECT_ID} --quiet || echo "Secret ${SECRET_WEBUI} not found."

echo "--- Deleting VPC Peering for Private Services ---"
gcloud services vpc-peerings delete --service=servicenetworking.googleapis.com --network=${VPC_NAME} --project=${PROJECT_ID} --quiet || echo "VPC peering not found."

echo "--- Deleting Private Service Access IP Range ---"
gcloud compute addresses delete ${PRIVATE_ACCESS_NAME} --global --project=${PROJECT_ID} --quiet || echo "Private service access address not found."

echo "--- Deleting Subnet and VPC ---"
gcloud compute networks subnets delete ${SUBNET_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Subnet not found."
gcloud compute networks delete ${VPC_NAME} --project=${PROJECT_ID} --quiet || echo "VPC not found."

echo "--- Deleting Router and NAT ---"
gcloud compute routers nats delete ${NAT_NAME} --router=${ROUTER_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet || echo "NAT not found."
gcloud compute routers delete ${ROUTER_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Router not found."

echo "--- Removing Cloud Run Invoker IAM policy for user ---"
gcloud run services remove-iam-policy-binding ${SERVICE_NAME} --region=${REGION} --project=${PROJECT_ID} --member=${IAP_MEMBER} --role="roles/run.invoker" --quiet || echo "IAM binding not found."

echo "Cleanup attempt finished."
