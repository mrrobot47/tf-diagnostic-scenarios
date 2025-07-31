#!/bin/bash
echo "This script provides a fallback for a failed 'terraform destroy'."
echo "Please enter the required values."

read -p "Enter your Project ID: " PROJECT_ID
read -p "Enter the Region (e.g., us-central1): " REGION
read -p "Enter the test user email (e.g., your-email@example.com): " TEST_USER_EMAIL

SERVICE_NAME="test-sc-9-iap-hello"
IAP_MEMBER="user:${TEST_USER_EMAIL}"

echo "--- Deleting Cloud Run Service: ${SERVICE_NAME} ---"
gcloud run services delete ${SERVICE_NAME} --region=${REGION} --project=${PROJECT_ID} --quiet || echo "Service not found or already deleted."

# Note: Deleting the IAP client and brand can have project-wide effects
# if other services use them. This part of the script is for clean test projects.

# Find the IAP Client ID to delete it
CLIENT_ID=$(gcloud iap oauth-clients list "projects/${PROJECT_ID}" --filter="displayName='Cloud Run IAP Test Client'" --format="value(name)")
if [[ -n "$CLIENT_ID" ]]; then
    echo "--- Deleting IAP Client: ${CLIENT_ID} ---"
    gcloud iap oauth-clients delete ${CLIENT_ID} --project=${PROJECT_ID} --quiet || echo "Client not found or already deleted."
else
    echo "--- No IAP Client with display name 'Cloud Run IAP Test Client' found to delete. ---"
fi

# Find the IAP Brand to delete it
BRAND_ID=$(gcloud iap oauth-brands list "projects/${PROJECT_ID}" --format="value(name)")
if [[ -n "$BRAND_ID" ]]; then
    echo "--- Deleting IAP Brand: ${BRAND_ID} ---"
    gcloud iap oauth-brands delete ${BRAND_ID} --project=${PROJECT_ID} --quiet || echo "Brand not found or already deleted."
fi

echo "--- Removing IAP IAM policy for user ---"
gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member=${IAP_MEMBER} \
    --role="roles/iap.httpsResourceAccessor" --quiet || echo "IAM binding not found."

echo "Cleanup attempt finished."
