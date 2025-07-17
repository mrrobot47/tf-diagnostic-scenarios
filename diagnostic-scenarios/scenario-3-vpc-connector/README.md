# Scenario 3: VPC Serverless Connector

## Goal
This scenario is a highly targeted test to determine if the GCP project allows the creation of a **VPC Serverless Connector**.

This resource is a critical component for enabling serverless services (like Cloud Run and Cloud Functions) to communicate with resources inside a private VPC network. A failure to provision this resource was the primary blocker for our initial serverless deployment plan.

This test is minimal by design. It creates a network and a subnet, then attempts to create the connector. There are no VMs or other services involved.

## Expected Output
A successful `terraform apply` will complete without errors and output the `connector_id`. This confirms that the necessary APIs (`vpcaccess.googleapis.com`) are enabled and there are no organization policies blocking the creation of this specific resource type. A failure here provides the definitive reason why a serverless-to-VPC architecture is not viable in this project.
