output "namespace" {
  description = "Kubernetes namespace created for the team."
  value       = kubernetes_namespace_v1.team.metadata[0].name
}

output "principal_arns" {
  description = "IAM principals granted EKS authentication and namespace RBAC access."
  value       = sort(values(var.principal_arns))
}

output "kubernetes_group" {
  description = "Kubernetes group bound to the team namespace."
  value       = local.team_kubernetes_group
}

output "access_entry_arns" {
  description = "EKS access entry ARNs created for the team's IAM principals."
  value       = { for name, entry in aws_eks_access_entry.team : name => entry.access_entry_arn }
}

output "cluster_describe_policy_arn" {
  description = "IAM policy ARN granting eks:DescribeCluster, if cluster describe access is enabled."
  value       = local.cluster_describe_policy_arn
}

output "role_binding_name" {
  description = "Kubernetes RoleBinding created in the team namespace."
  value       = kubernetes_role_binding_v1.team.metadata[0].name
}

output "resource_quota_name" {
  description = "Kubernetes ResourceQuota name when one is created."
  value       = length(kubernetes_resource_quota_v1.team) > 0 ? kubernetes_resource_quota_v1.team[0].metadata[0].name : null
}

output "aws_eks_update_kubeconfig_command" {
  description = "AWS CLI command an authorized principal can run after IAM and EKS access are applied."
  value       = "aws eks update-kubeconfig --name ${var.cluster_name} --region <aws-region>"
}
