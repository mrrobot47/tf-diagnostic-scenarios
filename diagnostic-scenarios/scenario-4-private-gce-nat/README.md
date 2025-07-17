# Scenario 4: Private GCE + Cloud NAT

## Goal
This scenario tests if a private GCE instance (one with no external IP address) is permitted to have outbound internet access via the managed **Cloud NAT** service.

This capability is critical for our GCE-based plan. It allows the private VM to pull container images from Docker Hub, run `apt-get update`, and communicate with any other required external services without being directly exposed to the internet.

## Expected Output
A successful `terraform apply` will provision all the networking resources and a private GCE instance. The true test of success is determined by checking the instance's serial port logs a few minutes after creation.

**To verify:**
```bash
gcloud compute instances get-serial-port-output nat-test-vm --zone=<YOUR_ZONE> --project=<YOUR_PROJECT_ID>
```
Look for a `"Hello from Google!"` message at the end of the log. This confirms that the startup script was able to successfully `curl` an external website, proving that the Cloud NAT gateway is working as expected. If the script fails with a connection timeout, it indicates a restriction on Cloud NAT or its associated resources.
