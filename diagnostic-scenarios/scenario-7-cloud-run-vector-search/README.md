# Scenario 7: Cloud Run to Vertex AI Vector Search

## Goal
This scenario is a high-fidelity test of the core requirement for the RAG agent: Can a **private Cloud Run service** successfully make API calls to a **Vertex AI Vector Search (Matching Engine) endpoint**?

This test validates the complete networking and permissions path:
1.  A Cloud Run service is made private using **Direct VPC Egress**.
2.  The service's private traffic correctly reaches the public Google API front-end via **Private Google Access**.
3.  The service's dedicated Service Account has the necessary IAM permissions (`roles/aiplatform.user`) to interact with Vector Search components.

## Expected Output
A successful `terraform apply` will deploy all resources, including a Vector Search Index and a public Endpoint. The test is validated by checking the Cloud Run service's logs.

**To verify:**
```bash
gcloud logging read "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"vector-search-connect-test\" AND severity>=DEFAULT" --project=<YOUR_PROJECT_ID> --limit=10
```
Look for a log entry that says `"SUCCESS: Successfully initialized client and found Vertex AI Index Endpoint."`. This proves the network path is open and IAM permissions are sufficient.

