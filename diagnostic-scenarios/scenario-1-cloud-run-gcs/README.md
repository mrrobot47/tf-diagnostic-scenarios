# Scenario 1: Cloud Run + GCS Bucket

## Goal
This scenario tests two fundamental capabilities of the GCP project:
1.  Can a basic, containerized web application be deployed using the serverless **Google Cloud Run** service?
2.  Can we create a **dedicated Service Account** and grant it IAM permissions to interact with another GCP service (in this case, a GCS bucket)?

A success here indicates that core serverless deployments and standard IAM bindings are permitted.

## Expected Output
A successful `terraform apply` will output a `cloud_run_service_url`. Visiting this URL in a browser should display the "Hello World" page from the test container. This confirms the deployment and permissions are working correctly.
