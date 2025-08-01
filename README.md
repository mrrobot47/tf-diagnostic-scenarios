# GCP Project Diagnostic Scenarios

This repository contains a series of isolated Terraform scenarios designed to test specific Google Cloud Platform (GCP) capabilities. Each scenario is independent and focuses on a minimal set of resources to quickly determine if a feature is enabled and permitted by the project's organization policies.

## How to Run

This project includes an interactive script, `run.sh`, that simplifies the process of running the diagnostic scenarios.

### Prerequisites

Before running the script, ensure you have the following tools installed:
*   `gcloud` (Google Cloud SDK)
*   `terraform`

### Execution

1.  **Make the script executable:**
    ```bash
    chmod +x run.sh
    ```

2.  **Run the script:**
    ```bash
    ./run.sh
    ```

The script will perform the following steps:
*   Check for the required dependencies (`gcloud`, `terraform`).
*   Prompt you to create a `.env` file to store your `PROJECT_ID` and `REGION` if it doesn't already exist.
*   Verify your `gcloud` authentication status.
*   Display a menu allowing you to select which scenario to run or destroy.

For each scenario, the script will automatically handle:
*   Prompting for any scenario-specific variables (like Zone or Domain Name).
*   Creating the necessary `terraform.tfvars` file.
*   Running `terraform init`, `terraform apply`, and `terraform destroy`.
*   Performing basic verification checks based on the scenario's expected output.

---

## Scenarios

Below is a quick reference summary of all diagnostic scenarios:

| #  | Scenario Name                        | What it Tests                                              |
|----|--------------------------------------|------------------------------------------------------------|
| 1  | Cloud Run + GCS Bucket               | Cloud Run deployment, GCS bucket, IAM binding              |
| 2  | GCE + External HTTPS Load Balancer   | VM, public load balancer, static IP, SSL cert              |
| 3  | VPC Serverless Connector             | VPC, subnet, serverless VPC connector                      |
| 4  | Private GCE + Cloud NAT              | Private VM with outbound internet via Cloud NAT             |
| 5  | Cloud Run + Cloud SQL                | Cloud Run with private Cloud SQL (Direct VPC Egress)       |
| 6  | Cloud Run + Redis                    | Cloud Run with private Memorystore Redis                   |
| 7  | Cloud Run + Vertex AI (Vector Search)| Cloud Run with Vertex AI Index Endpoint (private, peered)  |
| 8  | Cloud Run + Filestore                | Cloud Run with Filestore (NFS mount, private, peered)      |
| 9  | Cloud Run + IAP                      | Cloud Run with Identity-Aware Proxy (IAP)                  |
| 10 | Cloud Run Full State                 | Cloud Run, GCS, SQL, Redis, VPC, IAM, all together         |
| 11 | Cloud Run Full State with Build      | Full state + Cloud Build, Artifact Registry, Secret Manager|
| 12 | Cloud Run Agent Engine               | Cloud Run with Vertex AI Reasoning Engine (private, peered)|


