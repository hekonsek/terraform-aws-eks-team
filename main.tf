data "aws_eks_cluster" "team" {
  name = var.cluster_name
}

data "aws_iam_policy_document" "cluster_describe" {
  statement {
    sid       = "DescribeTeamCluster"
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = [data.aws_eks_cluster.team.arn]
  }
}

locals {
  namespace_name               = coalesce(var.namespace, var.team_name)
  team_kubernetes_group        = coalesce(var.kubernetes_group, "team-${var.team_name}")
  cluster_describe_policy_name = coalesce(var.cluster_describe_policy_name, "eks-${var.cluster_name}-credential-fetcher")
  manage_cluster_describe_policy = var.grant_cluster_describe_access && (
    length(var.iam_role_names) + length(var.iam_user_names) > 0
  )

  cluster_describe_policy_arn = local.manage_cluster_describe_policy ? (
    var.create_cluster_describe_policy ? aws_iam_policy.cluster_describe[0].arn : var.cluster_describe_policy_arn
  ) : null
}

resource "aws_eks_access_entry" "team" {
  for_each = var.create_access_entries ? var.principal_arns : {}

  cluster_name      = var.cluster_name
  principal_arn     = each.value
  kubernetes_groups = [local.team_kubernetes_group]
  type              = "STANDARD"

  tags = merge(
    {
      "app.kubernetes.io/managed-by" = "terraform"
      "eks-team-module/team"         = var.team_name
    },
    var.tags,
  )
}

resource "aws_iam_policy" "cluster_describe" {
  count = local.manage_cluster_describe_policy && var.create_cluster_describe_policy ? 1 : 0

  name        = local.cluster_describe_policy_name
  description = "Allows a tenant team to discover the ${var.cluster_name} EKS cluster when configuring kubectl."
  policy      = data.aws_iam_policy_document.cluster_describe.json

  tags = merge(
    {
      "app.kubernetes.io/managed-by" = "terraform"
      "eks-team-module/team"         = var.team_name
    },
    var.tags,
  )

  lifecycle {
    precondition {
      condition     = length(local.cluster_describe_policy_name) <= 128
      error_message = "The default cluster_describe_policy_name is too long. Set cluster_describe_policy_name to an IAM policy name of at most 128 characters."
    }
  }
}

resource "aws_iam_role_policy_attachment" "cluster_describe" {
  for_each = local.manage_cluster_describe_policy ? var.iam_role_names : []

  role       = each.value
  policy_arn = local.cluster_describe_policy_arn
}

resource "aws_iam_user_policy_attachment" "cluster_describe" {
  for_each = local.manage_cluster_describe_policy ? var.iam_user_names : []

  user       = each.value
  policy_arn = local.cluster_describe_policy_arn
}

resource "kubernetes_namespace_v1" "team" {
  metadata {
    name = local.namespace_name

    labels = merge(
      {
        "app.kubernetes.io/managed-by" = "terraform"
        "eks-team-module/team"         = var.team_name
      },
      var.namespace_labels,
    )

    annotations = var.namespace_annotations
  }

  lifecycle {
    precondition {
      condition     = length(var.principal_arns) > 0
      error_message = "Set at least one IAM principal ARN in principal_arns."
    }

    precondition {
      condition     = !local.manage_cluster_describe_policy || var.create_cluster_describe_policy || var.cluster_describe_policy_arn != null
      error_message = "Set cluster_describe_policy_arn when grant_cluster_describe_access is true and create_cluster_describe_policy is false."
    }
  }
}

resource "kubernetes_role_binding_v1" "team" {
  metadata {
    name      = var.role_binding_name
    namespace = kubernetes_namespace_v1.team.metadata[0].name

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "eks-team-module/team"         = var.team_name
    }
  }

  subject {
    kind      = "Group"
    name      = local.team_kubernetes_group
    api_group = "rbac.authorization.k8s.io"
  }

  role_ref {
    kind      = "ClusterRole"
    name      = var.kubernetes_cluster_role
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_resource_quota_v1" "team" {
  count = length(var.resource_quota_hard) > 0 ? 1 : 0

  metadata {
    name      = var.resource_quota_name
    namespace = kubernetes_namespace_v1.team.metadata[0].name

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "eks-team-module/team"         = var.team_name
    }
  }

  spec {
    hard = var.resource_quota_hard
  }
}
