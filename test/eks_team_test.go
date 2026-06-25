package test

import (
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

func TestEKSTeamModuleE2E(t *testing.T) {
	if os.Getenv("TERRATEST_SKIP_DEPLOY") != "" {
		t.Skip("TERRATEST_SKIP_DEPLOY set; skipping deployment")
	}

	region := firstSet("TF_VAR_region", "EKS_TEAM_TEST_REGION", "AWS_REGION", "AWS_DEFAULT_REGION")
	if region == "" {
		region = "us-east-1"
	}

	suffix := strings.ToLower(random.UniqueId())
	namePrefix := fmt.Sprintf("eks-team-e2e-%s", suffix)
	teamName := fmt.Sprintf("team-%s", suffix)
	namespace := fmt.Sprintf("%s-ns", teamName)

	terraformOptions := &terraform.Options{
		TerraformDir: ".",
		Vars: map[string]interface{}{
			"region":       region,
			"vpc_name":     fmt.Sprintf("%s-vpc", namePrefix),
			"cluster_name": namePrefix,
			"team_name":    teamName,
			"namespace":    namespace,
		},
		EnvVars: map[string]string{
			"AWS_REGION":       region,
			"TF_IN_AUTOMATION": "true",
		},
		NoColor: true,
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	tenantPrincipalARN := terraform.Output(t, terraformOptions, "tenant_principal_arn")
	require.Equal(t, namespace, terraform.Output(t, terraformOptions, "namespace"))
	require.Equal(t, []string{tenantPrincipalARN}, terraform.OutputList(t, terraformOptions, "principal_arns"))
	require.Equal(t, "team-"+teamName, terraform.Output(t, terraformOptions, "kubernetes_group"))
	require.NotEmpty(t, terraform.OutputMap(t, terraformOptions, "access_entry_arns"))
	require.Equal(t, "team-edit", terraform.Output(t, terraformOptions, "role_binding_name"))
	require.Equal(t, "team-quota", terraform.Output(t, terraformOptions, "resource_quota_name"))
}

func firstSet(names ...string) string {
	for _, name := range names {
		if value := strings.TrimSpace(os.Getenv(name)); value != "" {
			return value
		}
	}

	return ""
}
