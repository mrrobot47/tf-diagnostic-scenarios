# Scenario 12: Cloud Run + Vertex AI Reasoning Engine

## Goal
This scenario tests connection test to reasoning engines in Vertex AI using a containerized application deployed on Google Cloud Run. It verifies that the application can access the reasoning engines with the necessary permissions and network configurations.

A success here indicates that advanced serverless, IAM, and Vertex AI permissions are working, and that the project/network is not overly restricted for modern AI workloads.

## Pre-requisites
- A Google Cloud project with billing enabled.
- Agent Engine code https://github.com/gagan0123/dummy-agent deployed on GCP account where this scenario is being run.

## Expected Output
A successful `terraform apply` will output a `cloud_run_service_url`. Visiting this URL in a browser will show a web dashboard with:
- List of available Vertex AI Reasoning Engines
- Results of a test API call to a reasoning engine
- Status of authentication and network connectivity

## Cleanup
If `terraform destroy` fails, run the provided `cleanup.sh` script to manually remove all resources created by this scenario.
