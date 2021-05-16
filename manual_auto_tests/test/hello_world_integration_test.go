package test

import (
  "strings"
  "time"
  "fmt"
  http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
  "github.com/gruntwork-io/terratest/modules/random"
  "github.com/gruntwork-io/terratest/modules/terraform"
  "github.com/gruntwork-io/terratest/modules/test-structure"
  "testing"
)

const dbDirStage = "/home/ivan/study_terraform/up_first_aws_server/manual_auto_tests/live/stage/data-stores/mysql"
const appDirStage = "/home/ivan/study_terraform/up_first_aws_server/manual_auto_tests/live/stage/services/hello-world-app"

func TestHelloWorldAppStage(t *testing.T) {
  t.Parallel()

  // Deploy the MySQL DB
  dbOpts := createDbOpts(t, dbDirStage)
  defer terraform.Destroy(t, dbOpts)
  terraform.InitAndApply(t, dbOpts)

  // Deploy the hello-world-app
  helloOpts := createHelloOpts(dbOpts, appDirStage)
  defer terraform.Destroy(t, helloOpts)
  terraform.InitAndApply(t, helloOpts)

  // Validate the hello-world-app works
  validateHelloApp(t, helloOpts)
}

func createDbOpts(t *testing.T, terraformDir string) *terraform.Options {
  uniqueId := random.UniqueId()

  bucketForTesting := "us-east-2-ivandock-el"
  bucketRegionForTesting := "us-east-2"
  dbStateKey := fmt.Sprintf("%s/%s/terraform.tfstate", t.Name(), uniqueId)

  return &terraform.Options{
    TerraformDir: terraformDir,

    Vars: map[string]interface{}{
      "db_name": fmt.Sprintf("test%s", uniqueId),
      "db_password": "password",
    },

    BackendConfig: map[string]interface{}{
      "bucket": bucketForTesting,
      "region": bucketRegionForTesting,
      "key": dbStateKey,
      "encrypt": true,
    },
  }
}

func createHelloOpts(
      dbOpts *terraform.Options,
      terraformDir string) *terraform.Options {

      return &terraform.Options{
        TerraformDir: terraformDir,

        Vars: map[string]interface{}{
          "db_remote_state_bucket": dbOpts.BackendConfig["bucket"],
          "db_remote_state_key": dbOpts.BackendConfig["key"],
          "environment": dbOpts.Vars["db_name"],
        },

        // Retry up to 3 times, with 5 seconds between retries,
        // on known errors
        MaxRetries: 3,
        TimeBetweenRetries: 5 * time.Second,
        RetryableTerraformErrors: map[string]string{
            "RequestError: send request failed": "Throttling issue?",
        },
      }
}

func validateHelloApp(t *testing.T, helloOpts *terraform.Options) {
  albDnsName := terraform.OutputRequired(t, helloOpts, "alb_dns_name")
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

func TestHelloWorldAppStageWithStages(t *testing.T) {
  t.Parallel()

  stage := test_structure.RunTestStage

  // Deploy the MySQL DB
  defer stage(t, "teardown_db", func() { teardownDb(t, dbDirStage) })
  stage(t, "deploy_db", func() { deployDb(t, dbDirStage) })

  // Deploy the hello-world-app
  defer stage(t, "teardown_app", func() { teardownApp(t, appDirStage) })
  stage(t, "deploy_app", func() { deployApp(t, dbDirStage, appDirStage) })

  // Validate the hello-world-app works
  stage(t, "validate_app", func() { validateApp(t, appDirStage) })

  // Redeploy the hello-world-app
	stage(t, "redeploy_app", func() { redeployApp(t, appDirStage) })
}

func deployDb(t *testing.T, dbDir string) {
  dbOpts := createDbOpts(t, dbDir)

  // Save data to disk so that other test stages executed at a later 
  // time can read data back in
  test_structure.SaveTerraformOptions(t, dbDir, dbOpts)

  terraform.InitAndApply(t, dbOpts)
}

func teardownDb(t *testing.T, dbDir string) {
  dbOpts := test_structure.LoadTerraformOptions(t, dbDir)
  defer terraform.Destroy(t, dbOpts)
}

func deployApp(t *testing.T, dbDir string, helloAppDir string) {
  dbOpts := test_structure.LoadTerraformOptions(t, dbDir)
  helloOpts := createHelloOpts(dbOpts, helloAppDir)

  // Save data to disk so that other test stages executed at a later 
  // time can read data back in
  test_structure.SaveTerraformOptions(t, helloAppDir,helloOpts)

  terraform.InitAndApply(t, helloOpts)
}

func teardownApp(t *testing.T, helloAppDir string) {
  helloOpts := test_structure.LoadTerraformOptions(t, helloAppDir)
  defer terraform.Destroy(t, helloOpts)
}

func validateApp(t *testing.T, helloAppDir string) {
  helloOpts := test_structure.LoadTerraformOptions(t, helloAppDir)
  validateHelloApp(t, helloOpts)
}

func redeployApp(t *testing.T, helloAppDir string) {
  helloOpts := test_structure.LoadTerraformOptions(t, helloAppDir)

  albDnsName := terraform.OutputRequired(t, helloOpts, "alb_dns_name")
  url := fmt.Sprintf("http://%s", strings.Trim(albDnsName, "\""))

  // Start checking every 1s that the app is responding with a 200 OK
  stopChecking := make(chan bool, 1)
  waitGroup, _ := http_helper.ContinuouslyCheckUrl(
          t,
          url,
          stopChecking,
          1*time.Second,
  )

  // Update the server text and redeploy
  newServerText := "Hello, World, v2!"
  helloOpts.Vars["server_text"] = newServerText
  terraform.Apply(t, helloOpts)

  // Make sure the new version deployed
	maxRetries := 10
	timeBetweenRetries := 10 * time.Second
	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		url,
		maxRetries,
		timeBetweenRetries,
		func(status int, body string) bool {
			return status == 200 &&
				strings.Contains(body, newServerText)
		},
	)

  // Stop checking
  stopChecking <- true
  waitGroup.Wait()
}
