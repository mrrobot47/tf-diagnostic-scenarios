# Scenario 2: GCE + External HTTPS Load Balancer

## Goal
This scenario tests if the GCP project has the necessary permissions to provision public-facing networking resources. Specifically, it tests:
1.  Can a **Global External HTTPS Load Balancer** be created?
2.  Can a **static external IP address** be reserved and assigned to the load balancer?
3.  Can a **Google-managed SSL certificate** be provisioned?

A success here indicates that you can expose applications to the internet using standard IaaS components.

## Expected Output
A successful `terraform apply` will output a `load_balancer_ip`. The SSL certificate may take 15-20 minutes to provision. The primary success metric is the *successful creation* of all networking resources, even if the certificate for the placeholder domain remains in a `PROVISIONING` state.
