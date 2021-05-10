package test

import (
  "strings"
  "time"
  "fmt"
  "github.com/gruntwork-io/terratest/modules/http-helper"
  "github.com/gruntwork-io/terratest/modules/random"
  "github.com/gruntwork-io/terratest/modules/terraform"
  "testing"
)

func TestAlbExample(t *testing.T) {
  t.Parallel()
  opts := &terraform.Options{
    TerraformDir: "/home/ivan/study_terraform/up_first_aws_server/manual_auto_tests/examples/alb",

    Vars: map[string]interface{}{
      "alb_name": fmt.Sprintf("test-%s", random.UniqueId()),
    },
  }

  // Clean up everything at the end of the test
  defer terraform.Destroy(t, opts)

  // Deploy the example
  terraform.InitAndApply(t, opts)

  // Get the URL of the ALB
  albDnsName := terraform.OutputRequired(t, opts, "alb_dns_name")
  url := fmt.Sprintf("http://%s", strings.Trim(albDnsName, "\""))

  // Test that the ALB's default action is working and returns a 404

  expectedStatus := 404
  expectedBody := "404: page not found"

  maxRetries := 10
  timeBetweenRetries := 10 * time.Second

  http_helper.HttpGetWithRetry(
          t,
          url,
          expectedStatus,
          expectedBody,
          maxRetries,
          timeBetweenRetries,
  )
}
