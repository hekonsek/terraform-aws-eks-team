terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.35.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.38.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

module "vpc" {
  source = "git::https://github.com/hekonsek/terraform-aws-vpc.git"

  network_name       = var.vpc_name
  cluster_name       = var.cluster_name
  enable_nat_gateway = false
}

resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "tenant" {
  name = "${var.cluster_name}-tenant"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_eks_cluster" "team" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = module.vpc.private_subnet_ids
    endpoint_private_access = false
    endpoint_public_access  = true
  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

data "aws_eks_cluster" "team" {
  name = aws_eks_cluster.team.name

  depends_on = [aws_eks_cluster.team]
}

data "aws_eks_cluster_auth" "team" {
  name = aws_eks_cluster.team.name

  depends_on = [aws_eks_cluster.team]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.team.endpoint
  token                  = data.aws_eks_cluster_auth.team.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.team.certificate_authority[0].data)
}

module "test" {
  source = "./.."

  cluster_name = aws_eks_cluster.team.name
  team_name    = var.team_name
  namespace    = var.namespace
  principal_arns = {
    tenant = aws_iam_role.tenant.arn
  }

  kubernetes_cluster_role = "edit"

  resource_quota_hard = {
    "requests.cpu"    = "1"
    "requests.memory" = "1Gi"
    "limits.cpu"      = "2"
    "limits.memory"   = "2Gi"
    "pods"            = "10"
  }

  depends_on = [aws_eks_cluster.team]
}

output "namespace" {
  description = "Namespace created by the team module."
  value       = module.test.namespace
}

output "principal_arns" {
  description = "IAM principals granted team access by the module."
  value       = module.test.principal_arns
}

output "kubernetes_group" {
  description = "Kubernetes group assigned to the temporary tenant role."
  value       = module.test.kubernetes_group
}

output "tenant_principal_arn" {
  description = "Temporary IAM role ARN granted tenant access by the module."
  value       = aws_iam_role.tenant.arn
}

output "access_entry_arns" {
  description = "EKS access entries created by the team module."
  value       = module.test.access_entry_arns
}

output "role_binding_name" {
  description = "RoleBinding created by the team module."
  value       = module.test.role_binding_name
}

output "resource_quota_name" {
  description = "ResourceQuota created by the team module."
  value       = module.test.resource_quota_name
}
