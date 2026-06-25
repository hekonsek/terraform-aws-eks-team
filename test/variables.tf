variable "region" {
  description = "AWS region in which to run the integration test."
  type        = string
  default     = "us-east-1"
}

variable "vpc_name" {
  description = "Name for the test VPC."
  type        = string
}

variable "cluster_name" {
  description = "Name for the test EKS cluster."
  type        = string
}

variable "team_name" {
  description = "Name of the team created by the module."
  type        = string
}

variable "namespace" {
  description = "Namespace created by the module."
  type        = string
}
