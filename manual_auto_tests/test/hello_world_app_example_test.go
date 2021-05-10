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

func TestHelloWorldExample(t *testing.T) {
  t.Parallel()

  opts := &terraform.Options{
    TerraformDir: "../examples/hello-world-app/standalone",

    Vars: map[string]interface{}{
      "mysql_config": map[string]interface{}{
          "address": "mock-value-for-test",
          "port": 3306,
      },
      "environment": fmt.Sprintf("test-%s", random.UniqueId()),
    },
  }

  // Clean up everything at the end of the test
  defer terraform.Destroy(t, opts)

  // Deploy the example
  terraform.InitAndApply(t, opts)

  // Get the URL of the ALB
  albDnsName := terraform.OutputRequired(t, opts, "alb_dns_name")
  url := fmt.Sprintf("http://%s", strings.Trim(albDnsName, "\""))

  maxRetries := 10
  timeBetweenRetries := 10 * time.Second

  http_helper.HttpGetWithRetryWithCustomValidation(
          t,
          url,
          maxRetries,
          timeBetweenRetries,
          func(status int, body string) bool {
              return status == 200 &&
                  strings.Contains(body, "Hello, World")
          },
  )
}
