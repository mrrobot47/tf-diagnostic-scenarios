# Scenario 5: Cloud Run + Cloud SQL (with Direct VPC Egress)

## Goal
This scenario tests the modern, preferred method for a Cloud Run service to connect to a **private Cloud SQL (PostgreSQL) instance** using **Direct VPC Egress**.

This architecture is simpler and more performant than the classic VPC Connector model. It tests:
1.  A VPC Network configured with a `/24` subnet.
2.  A **Private Service Access** connection to allow Google services to peer with the VPC.
3.  The ability for Cloud Run to directly join the VPC network via its `network_interfaces` configuration.
4.  The correct IAM permissions (`roles/cloudsql.client`) for the Cloud Run service account.

## Expected Output
A successful `terraform apply` will deploy all resources. The definitive test is to check the Cloud Run service's logs and visit the deployed service URL.

**To verify logs:**
```bash
gcloud logging read "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"sql-direct-connect-test\" AND severity>=DEFAULT" --project=<YOUR_PROJECT_ID> --limit=10 --format='value(textPayload)'
```
Look for a log entry containing:
```
SUCCESS: Connected to Cloud SQL and ran 'SELECT 1'.
```
This confirms the networking path and IAM permissions are correctly configured. If you do not see this, check your service code and ensure logging is enabled for stdout/stderr.

**To verify via HTTP:**
After deployment, get the service URL:
```bash
gcloud run services describe sql-direct-connect-test --region=<YOUR_REGION> --project=<YOUR_PROJECT_ID> --format='value(status.url)'
```
Then visit the URL in your browser or with curl, passing the Cloud Run identity header:
```bash
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" <SERVICE_URL>
```
The response will show connection details, including Cloud SQL connectivity status. If successful, you should see output confirming the connection and query result.