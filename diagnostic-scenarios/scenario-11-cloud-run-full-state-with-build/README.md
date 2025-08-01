# Scenario 11: Cloud Run with Full State and Cloud Build Pipeline

## Goal
This scenario is a comprehensive, end-to-end test of a stateful serverless architecture, with the added complexity of a fully automated CI/CD pipeline. It validates that a single **Google Cloud Run** service can be built and deployed via **Cloud Build** from a connected GitHub repository, and can simultaneously and securely connect to a **GCS Bucket**, a private **Cloud SQL (PostgreSQL)** instance, and a private **Memorystore for Redis** instance.

This scenario demonstrates:
1. Automated build and deployment of a Docker image to Cloud Run using Cloud Build triggers and Artifact Registry.
2. Creation of a VPC and subnet suitable for Direct VPC Egress.
3. Setup of Private Service Access for SQL and Redis.
4. Provisioning of private-only Cloud SQL and Redis instances.
5. Creation of a GCS Bucket for persistent storage.
6. Secure management of secrets using Secret Manager.
7. Configuration of dedicated Service Accounts with granular IAM permissions for both Cloud Run and Cloud Build.
8. The ability of the Cloud Run service to connect to all three backends from within the VPC and serve a web page.

## Expected Output
A successful `terraform apply` will deploy all resources and set up the build pipeline. The definitive test is to push a commit to the configured GitHub branch, which should trigger a Cloud Build pipeline that builds and deploys the service to Cloud Run. Visit the `cloud_run_service_url` provided in the output (you may need to authenticate with the provided `test_user_email`). The web page will display a status report table. All three services (Cloud SQL, Redis, and GCS) should show a "✅ SUCCESS" status.

## Resources Created
- Cloud Run service: `test-sc-11-open-webui`
- Cloud Build trigger: `test-sc-11-open-webui-trigger`
- Artifact Registry repository: `test-sc-11-open-webui-images`
- Cloud SQL instance: `test-sc-11-postgres-db`
- Memorystore for Redis instance: `test-sc-11-redis-instance`
- GCS bucket: `test-sc-11-storage-bucket-<PROJECT_ID>`
- VPC: `test-sc-11-vpc` and subnet: `test-sc-11-subnet`
- Private Service Access IP: `test-sc-11-private-access`
- Router: `test-sc-11-router` and NAT: `test-sc-11-nat`
- Service Accounts: `test-sc-11-cloudrun-sa`, `test-sc-11-cloudbuild-sa`
- Secret Manager secrets: `test-sc-11-database-url`, `test-sc-11-redis-url`, `test-sc-11-webui-secret-key`
- IAM bindings for service accounts and Cloud Run invoker

## Cleanup
To remove all resources, run the provided `cleanup.sh` script. The script will prompt for any required values not set in your environment or `.env` file, and will attempt to delete all resources created by this scenario.
