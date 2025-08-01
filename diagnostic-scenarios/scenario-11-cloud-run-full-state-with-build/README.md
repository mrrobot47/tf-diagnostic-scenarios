# Scenario 10: Cloud Run with Full State (GCS, SQL, Redis)

## Goal
This is a comprehensive, end-to-end scenario that tests the complete stateful serverless architecture. It validates if a single **Google Cloud Run** service can simultaneously and securely connect to a **GCS Bucket**, a private **Cloud SQL (PostgreSQL)** instance, and a private **Memorystore for Redis** instance.

This test is the culmination of many previous scenarios and validates:
1.  The creation of a VPC and a subnet suitable for Direct VPC Egress.
2.  The setup of a Private Service Access connection for SQL and Redis.
3.  The provisioning of private-only Cloud SQL and Redis instances.
4.  The creation of a GCS Bucket.
5.  The configuration of a dedicated Service Account with the correct, granular IAM permissions (`cloudsql.client`, `redis.client`, `storage.objectAdmin`).
6.  The ability of a Cloud Run service to connect to all three backends from within the VPC and serve a web page.

## Expected Output
A successful `terraform apply` will deploy all resources. The definitive test is to visit the `cloud_run_service_url` provided in the output (you may need to authenticate with the provided `test_user_email`). The web page will display a status report table. All three services (Cloud SQL, Redis, and GCS) should show a "✅ SUCCESS" status.
