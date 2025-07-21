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

### Scenario 1: Cloud Run + GCS Bucket

#### Goal
This scenario tests two fundamental capabilities of the GCP project:
1.  Can a basic, containerized web application be deployed using the serverless **Google Cloud Run** service?
2.  Can we create a **dedicated Service Account** and grant it IAM permissions to interact with another GCP service (in this case, a GCS bucket)?

A success here indicates that core serverless deployments and standard IAM bindings are permitted.

#### Expected Output
A successful `terraform apply` will output a `cloud_run_service_url`. Visiting this URL in a browser should display the "Hello World" page from the test container. This confirms the deployment and permissions are working correctly.

---

### Scenario 2: GCE + External HTTPS Load Balancer

#### Goal
This scenario tests if the GCP project has the necessary permissions to provision public-facing networking resources. Specifically, it tests:
1.  Can a **Global External HTTPS Load Balancer** be created?
2.  Can a **static external IP address** be reserved and assigned to the load balancer?
3.  Can a **Google-managed SSL certificate** be provisioned?

A success here indicates that you can expose applications to the internet using standard IaaS components.

#### Expected Output
A successful `terraform apply` will output a `load_balancer_ip`. The SSL certificate may take 15-20 minutes to provision. The primary success metric is the *successful creation* of all networking resources, even if the certificate for the placeholder domain remains in a `PROVISIONING` state.

---

### Scenario 3: VPC Serverless Connector

#### Goal
This scenario is a highly targeted test to determine if the GCP project allows the creation of a **VPC Serverless Connector**.

This resource is a critical component for enabling serverless services (like Cloud Run and Cloud Functions) to communicate with resources inside a private VPC network. A failure to provision this resource was the primary blocker for our initial serverless deployment plan.

This test is minimal by design. It creates a network and a subnet, then attempts to create the connector. There are no VMs or other services involved.

#### Expected Output
A successful `terraform apply` will complete without errors and output the `connector_id`. This confirms that the necessary APIs (`vpcaccess.googleapis.com`) are enabled and there are no organization policies blocking the creation of this specific resource type. A failure here provides the definitive reason why a serverless-to-VPC architecture is not viable in this project.

---

### Scenario 4: Private GCE + Cloud NAT

#### Goal
This scenario tests if a private GCE instance (one with no external IP address) is permitted to have outbound internet access via the managed **Cloud NAT** service.

This capability is critical for our GCE-based plan. It allows the private VM to pull container images from Docker Hub, run `apt-get update`, and communicate with any other required external services without being directly exposed to the internet.

#### Expected Output
A successful `terraform apply` will provision all the networking resources and a private GCE instance. The true test of success is determined by checking the instance's serial port logs a few minutes after creation.

**To verify:**
```bash
gcloud compute instances get-serial-port-output test-sc-4-vm --zone=<YOUR_ZONE> --project=<YOUR_PROJECT_ID>
```
Look for a `"Hello from Google!"` message at the end of the log. This confirms that the startup script was able to successfully `curl` an external website, proving that the Cloud NAT gateway is working as expected. If the script fails with a connection timeout, it indicates a restriction on Cloud NAT or its associated resources.