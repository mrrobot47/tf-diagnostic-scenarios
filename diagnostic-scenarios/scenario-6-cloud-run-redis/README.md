# Scenario 6: Cloud Run + Redis (with Direct VPC Egress)

## Goal
This scenario tests if a Cloud Run service can connect to a **private Memorystore for Redis instance** using the modern **Direct VPC Egress** feature. This is a key test for implementing performant, stateful caching in a serverless architecture.

This architecture is simpler and more cost-effective than the classic VPC Connector model. It requires:
1.  A VPC Network configured with a `/24` subnet (a requirement for Direct VPC Egress).
2.  A **Private Service Access** connection for Memorystore to peer with the VPC.
3.  The ability for Cloud Run to directly join the VPC network via its `network_interfaces` configuration.
4.  The correct IAM permissions (`roles/redis.client`) for the Cloud Run service account.

## Expected Output
A successful `terraform apply` will deploy all resources. The definitive test is to check the Cloud Run service's logs.

**To verify:**
```bash
gcloud logging read "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"redis-direct-connect-test\" AND severity>=DEFAULT" --project=<YOUR_PROJECT_ID> --limit=10
```
Look for a log entry that says `"SUCCESS: PING responded with PONG."`. This confirms that Cloud Run was able to connect to the private Redis instance and receive a response.

```