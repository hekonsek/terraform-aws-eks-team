variable "cluster_name" {
  description = "Name of the existing EKS cluster that the team will access."
  type        = string
}

variable "team_name" {
  description = "Short Kubernetes-safe team name. Used in labels, Kubernetes group names, and as the namespace name when namespace is null."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.team_name)) && length(var.team_name) <= 63
    error_message = "team_name must be a valid Kubernetes DNS label: lowercase alphanumeric characters or hyphens, starting and ending with an alphanumeric character, and at most 63 characters."
  }
}

variable "namespace" {
  description = "Namespace to create for the team. Defaults to team_name when null."
  type        = string
  default     = null

  validation {
    condition     = var.namespace == null || (can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.namespace)) && length(var.namespace) <= 63)
    error_message = "namespace must be null or a valid Kubernetes DNS label: lowercase alphanumeric characters or hyphens, starting and ending with an alphanumeric character, and at most 63 characters."
  }
}

variable "principal_arns" {
  description = "Map of stable principal identifiers to IAM user or role ARNs. The keys identify EKS access entries; values may be unknown until apply. These principals become members of kubernetes_group."
  type        = map(string)

  validation {
    condition = alltrue([
      for arn in var.principal_arns : can(regex("^arn:(aws|aws-us-gov|aws-cn):iam::[0-9]{12}:(role|user)/.+$", arn))
    ])
    error_message = "principal_arns values must be IAM user or role ARNs, not STS assumed-role ARNs."
  }
}

variable "kubernetes_group" {
  description = "Kubernetes group assigned to every EKS access entry. Defaults to team-<team_name>."
  type        = string
  default     = null

  validation {
    condition     = var.kubernetes_group == null || (length(var.kubernetes_group) > 0 && !startswith(var.kubernetes_group, "system:") && !startswith(var.kubernetes_group, "eks:"))
    error_message = "kubernetes_group must not be empty or start with the reserved system: or eks: prefixes."
  }
}

variable "create_access_entries" {
  description = "Whether to create EKS STANDARD access entries for principal_arns. Set false only when equivalent access entries are managed elsewhere."
  type        = bool
  default     = true
}

variable "kubernetes_cluster_role" {
  description = "Existing Kubernetes ClusterRole to bind to the team group in its namespace."
  type        = string
  default     = "edit"
}

variable "role_binding_name" {
  description = "Name of the Kubernetes RoleBinding created in the team namespace."
  type        = string
  default     = "team-edit"
}

variable "namespace_labels" {
  description = "Additional labels to set on the team namespace."
  type        = map(string)
  default     = {}
}

variable "namespace_annotations" {
  description = "Annotations to set on the team namespace."
  type        = map(string)
  default     = {}
}

variable "resource_quota_name" {
  description = "Name of the optional ResourceQuota created when resource_quota_hard is not empty."
  type        = string
  default     = "team-quota"
}

variable "resource_quota_hard" {
  description = "Optional Kubernetes ResourceQuota hard limits for the team namespace. Leave empty to skip creating a ResourceQuota."
  type        = map(string)
  default     = {}
}

variable "grant_cluster_describe_access" {
  description = "Whether to attach an IAM policy allowing eks:DescribeCluster to iam_role_names and iam_user_names. No policy is created when both sets are empty. This permission is needed for aws eks update-kubeconfig."
  type        = bool
  default     = true
}

variable "create_cluster_describe_policy" {
  description = "Whether to create the customer-managed IAM policy used for eks:DescribeCluster. Set false to reuse cluster_describe_policy_arn."
  type        = bool
  default     = true
}

variable "cluster_describe_policy_name" {
  description = "Name of the customer-managed IAM policy for eks:DescribeCluster. Defaults to eks-<cluster_name>-credential-fetcher."
  type        = string
  default     = null

  validation {
    condition     = var.cluster_describe_policy_name == null || (length(var.cluster_describe_policy_name) >= 1 && length(var.cluster_describe_policy_name) <= 128)
    error_message = "cluster_describe_policy_name must be null or between 1 and 128 characters."
  }
}

variable "cluster_describe_policy_arn" {
  description = "ARN of an existing IAM policy granting eks:DescribeCluster for this cluster. Required when grant_cluster_describe_access is true and create_cluster_describe_policy is false."
  type        = string
  default     = null
}

variable "iam_role_names" {
  description = "IAM role names in the configured AWS account to receive the cluster describe policy. Normally these correspond to role ARNs in principal_arns."
  type        = set(string)
  default     = []
}

variable "iam_user_names" {
  description = "IAM user names in the configured AWS account to receive the cluster describe policy. Normally these correspond to user ARNs in principal_arns."
  type        = set(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to EKS access entries and the optional IAM policy."
  type        = map(string)
  default     = {}
}
