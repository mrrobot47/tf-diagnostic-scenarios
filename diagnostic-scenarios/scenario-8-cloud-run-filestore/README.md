# Scenario 8: Cloud Run + Filestore (NFS)

## Goal
This scenario tests if a Cloud Run service is permitted to mount a persistent, shared network filesystem using **Cloud Filestore (NFS)**.

This capability is essential for the RAG (Retrieval-Augmented Generation) features of Open WebUI, allowing multiple serverless instances to read from and write to a common location for user-uploaded documents. This test validates the `volumes` and `volume_mounts` functionality in Cloud Run when connected to a private VPC.

## Expected Output
A successful `terraform apply` will deploy all resources. The test is validated by checking the service's logs a few minutes after deployment.

**To verify:**
```bash
gcloud logging read "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"filestore-mount-test\" AND severity>=DEFAULT" --project=<YOUR_PROJECT_ID> --limit=10
```
Look for a log entry containing `"SUCCESS: test.txt created in NFS mount."`. This proves the volume was successfully mounted as read-write by the Cloud Run container.

```