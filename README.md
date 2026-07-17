# Terraform module for AWS EKS team onboarding

This module onboards a tenant team to an existing shared Amazon EKS cluster. It creates a namespace, namespace-scoped RBAC, optional resource quotas, and EKS access entries that map IAM roles or users to one Kubernetes group.

It uses [EKS access entries](https://docs.aws.amazon.com/eks/latest/userguide/access-entries.html), not the legacy `aws-auth` ConfigMap. The target EKS cluster must use the `API` or `API_AND_CONFIG_MAP` authentication mode. The caller configures the `aws` provider for the cluster's AWS account and the `kubernetes` provider for the target cluster.

The module also can attach a minimal `eks:DescribeCluster` policy to named IAM roles or users in the configured AWS account. That permission lets the principals run `aws eks update-kubeconfig`; it does not grant Kubernetes permissions. EKS access entries and the namespace RoleBinding provide Kubernetes access.

## Example

```hcl
data "aws_eks_cluster" "shared" {
  name = "platform-production"
}

data "aws_eks_cluster_auth" "shared" {
  name = data.aws_eks_cluster.shared.name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.shared.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.shared.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.shared.token
}

module "payments_team" {
  source = "git::https://github.com/hekonsek/terraform-aws-eks-team.git?ref=v0.1.0"

  cluster_name = data.aws_eks_cluster.shared.name
  team_name    = "payments"
  namespace    = "payments-prod"

  principal_arns = {
    payments-developer = "arn:aws:iam::123456789012:role/payments-developer"
  }

  # These attachments are optional, but a principal normally needs this
  # permission to run aws eks update-kubeconfig.
  iam_role_names = ["payments-developer"]

  kubernetes_cluster_role = "edit"

  resource_quota_hard = {
    "requests.cpu"    = "4"
    "requests.memory" = "8Gi"
    "limits.cpu"      = "8"
    "limits.memory"   = "16Gi"
    "pods"            = "40"
  }
}
```

After apply, an authorized team member can configure `kubectl` with:

```bash
aws eks update-kubeconfig --name platform-production --region <aws-region>
```

## Reusing the cluster-describe policy

AWS IAM policy names are account-global. When onboarding a second team to the same cluster, create the cluster-describe policy only once. For subsequent module instances, set `create_cluster_describe_policy = false` and provide the policy ARN from the first instance:

```hcl
module "data_team" {
  source = "git::https://github.com/hekonsek/terraform-aws-eks-team.git?ref=v0.1.0"

  cluster_name   = "platform-production"
  team_name      = "data"
  principal_arns = {
    data-developer = "arn:aws:iam::123456789012:role/data-developer"
  }
  iam_role_names = ["data-developer"]

  create_cluster_describe_policy = false
  cluster_describe_policy_arn    = module.payments_team.cluster_describe_policy_arn
}
```

For cross-account principals, EKS access entries can be created for their IAM ARNs, but this module cannot attach the cluster-describe policy in the other account. Attach an equivalent `eks:DescribeCluster` policy in that account, or configure kubeconfig by another approved mechanism.

## Operational notes

- `principal_arns` maps stable, unique identifiers to IAM user or role ARNs. Do not provide STS assumed-role ARNs. Map keys are intentionally separate from the ARN values so the module also accepts IAM roles created in the same apply.
- The module creates a `STANDARD` EKS access entry with the Kubernetes group `team-<team_name>` by default. Override `kubernetes_group` only when integrating with existing RBAC conventions.
- The default `edit` ClusterRole is namespace scoped by the RoleBinding. It does not grant cluster-wide permissions.
- A ResourceQuota limits aggregate namespace resources. It does not require every workload to specify requests and limits; use an admission policy or a LimitRange if that is required by your platform standards.
- Creating a namespace is not network isolation. Configure network policies separately if your CNI and platform policy require tenant traffic isolation.

## Development

```bash
make fmt
make validate
make docs
```

## Testing

The Terratest integration test creates a real VPC and EKS control plane, creates an EKS access entry and namespace resources, then destroys them. It does not create a node group, but EKS and VPC resources can incur AWS charges while the test runs.

The test creates a dedicated temporary IAM tenant role for its EKS access entry. The AWS identity running the test needs permissions to create and delete the VPC, EKS cluster, IAM roles, EKS access entry, and Kubernetes resources.

```bash
export AWS_REGION=us-east-1
make test
```

Set `TERRATEST_SKIP_DEPLOY=1` to compile and run the test package without provisioning AWS resources.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.35.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.38.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.35.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.38.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eks_access_entry.team](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry) | resource |
| [aws_iam_policy.cluster_describe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role_policy_attachment.cluster_describe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_user_policy_attachment.cluster_describe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user_policy_attachment) | resource |
| [kubernetes_namespace_v1.team](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_resource_quota_v1.team](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/resource_quota_v1) | resource |
| [kubernetes_role_binding_v1.team](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding_v1) | resource |
| [aws_eks_cluster.team](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_policy_document.cluster_describe](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_describe_policy_arn"></a> [cluster\_describe\_policy\_arn](#input\_cluster\_describe\_policy\_arn) | ARN of an existing IAM policy granting eks:DescribeCluster for this cluster. Required when grant\_cluster\_describe\_access is true and create\_cluster\_describe\_policy is false. | `string` | `null` | no |
| <a name="input_cluster_describe_policy_name"></a> [cluster\_describe\_policy\_name](#input\_cluster\_describe\_policy\_name) | Name of the customer-managed IAM policy for eks:DescribeCluster. Defaults to eks-<cluster\_name>-credential-fetcher. | `string` | `null` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the existing EKS cluster that the team will access. | `string` | n/a | yes |
| <a name="input_create_access_entries"></a> [create\_access\_entries](#input\_create\_access\_entries) | Whether to create EKS STANDARD access entries for principal\_arns. Set false only when equivalent access entries are managed elsewhere. | `bool` | `true` | no |
| <a name="input_create_cluster_describe_policy"></a> [create\_cluster\_describe\_policy](#input\_create\_cluster\_describe\_policy) | Whether to create the customer-managed IAM policy used for eks:DescribeCluster. Set false to reuse cluster\_describe\_policy\_arn. | `bool` | `true` | no |
| <a name="input_grant_cluster_describe_access"></a> [grant\_cluster\_describe\_access](#input\_grant\_cluster\_describe\_access) | Whether to attach an IAM policy allowing eks:DescribeCluster to iam\_role\_names and iam\_user\_names. No policy is created when both sets are empty. This permission is needed for aws eks update-kubeconfig. | `bool` | `true` | no |
| <a name="input_iam_role_names"></a> [iam\_role\_names](#input\_iam\_role\_names) | IAM role names in the configured AWS account to receive the cluster describe policy. Normally these correspond to role ARNs in principal\_arns. | `set(string)` | `[]` | no |
| <a name="input_iam_user_names"></a> [iam\_user\_names](#input\_iam\_user\_names) | IAM user names in the configured AWS account to receive the cluster describe policy. Normally these correspond to user ARNs in principal\_arns. | `set(string)` | `[]` | no |
| <a name="input_kubernetes_cluster_role"></a> [kubernetes\_cluster\_role](#input\_kubernetes\_cluster\_role) | Existing Kubernetes ClusterRole to bind to the team group in its namespace. | `string` | `"edit"` | no |
| <a name="input_kubernetes_group"></a> [kubernetes\_group](#input\_kubernetes\_group) | Kubernetes group assigned to every EKS access entry. Defaults to team-<team\_name>. | `string` | `null` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace to create for the team. Defaults to team\_name when null. | `string` | `null` | no |
| <a name="input_namespace_annotations"></a> [namespace\_annotations](#input\_namespace\_annotations) | Annotations to set on the team namespace. | `map(string)` | `{}` | no |
| <a name="input_namespace_labels"></a> [namespace\_labels](#input\_namespace\_labels) | Additional labels to set on the team namespace. | `map(string)` | `{}` | no |
| <a name="input_principal_arns"></a> [principal\_arns](#input\_principal\_arns) | Map of stable principal identifiers to IAM user or role ARNs. The keys identify EKS access entries; values may be unknown until apply. These principals become members of kubernetes\_group. | `map(string)` | n/a | yes |
| <a name="input_resource_quota_hard"></a> [resource\_quota\_hard](#input\_resource\_quota\_hard) | Optional Kubernetes ResourceQuota hard limits for the team namespace. Leave empty to skip creating a ResourceQuota. | `map(string)` | `{}` | no |
| <a name="input_resource_quota_name"></a> [resource\_quota\_name](#input\_resource\_quota\_name) | Name of the optional ResourceQuota created when resource\_quota\_hard is not empty. | `string` | `"team-quota"` | no |
| <a name="input_role_binding_name"></a> [role\_binding\_name](#input\_role\_binding\_name) | Name of the Kubernetes RoleBinding created in the team namespace. | `string` | `"team-edit"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to EKS access entries and the optional IAM policy. | `map(string)` | `{}` | no |
| <a name="input_team_name"></a> [team\_name](#input\_team\_name) | Short Kubernetes-safe team name. Used in labels, Kubernetes group names, and as the namespace name when namespace is null. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_access_entry_arns"></a> [access\_entry\_arns](#output\_access\_entry\_arns) | EKS access entry ARNs created for the team's IAM principals. |
| <a name="output_cluster_describe_policy_arn"></a> [cluster\_describe\_policy\_arn](#output\_cluster\_describe\_policy\_arn) | IAM policy ARN granting eks:DescribeCluster, if cluster describe access is enabled. |
| <a name="output_kubernetes_group"></a> [kubernetes\_group](#output\_kubernetes\_group) | Kubernetes group bound to the team namespace. |
| <a name="output_namespace"></a> [namespace](#output\_namespace) | Kubernetes namespace created for the team. |
| <a name="output_principal_arns"></a> [principal\_arns](#output\_principal\_arns) | IAM principals granted EKS authentication and namespace RBAC access. |
| <a name="output_resource_quota_name"></a> [resource\_quota\_name](#output\_resource\_quota\_name) | Kubernetes ResourceQuota name when one is created. |
| <a name="output_role_binding_name"></a> [role\_binding\_name](#output\_role\_binding\_name) | Kubernetes RoleBinding created in the team namespace. |
<!-- END_TF_DOCS -->
