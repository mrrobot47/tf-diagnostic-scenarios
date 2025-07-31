# Scenario 9: Cloud Run with Identity-Aware Proxy (IAP)

## Goal
This scenario is the definitive test for securing a serverless web application. It determines if the GCP project allows a **Google Cloud Run** service to be protected by **Identity-Aware Proxy (IAP)**.

This scenario has two modes, controlled by the `create_oauth_client` variable:

1.  **Auto-Create Mode (`create_oauth_client = true`):** This mode tests if you have permissions to create a new IAP Brand and OAuth Client. This is useful for environments where you have broader permissions.
2.  **Existing Client Mode (`create_oauth_client = false`):** This mode tests the more common enterprise scenario where you are given existing OAuth credentials and must apply them to a service.

A successful test in either mode validates that IAP can be successfully bound to a live Cloud Run service.

## Expected Output
A successful `terraform apply` will deploy the service and IAP configuration. The key test is to visit the `cloud_run_service_url` provided in the output.

*   You **SHOULD NOT** see the "Hello World" application immediately.
*   You **SHOULD** be redirected to a standard Google login page.
*   After authenticating as the `test_user_email` you provided, you **SHOULD** be redirected back to the service and see the "Hello World" page.

This sequence confirms that IAP is successfully intercepting and authorizing requests.
