variable "aws_region" {
  description = "AWS region for the lab resources."
  type        = string
  default     = "eu-central-1"
}

variable "aws_account_id" {
  description = "Expected AWS account ID for this personal lab."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Provide a 12-digit AWS account ID."
  }
}

variable "document_bucket_name" {
  description = "Globally unique name for the document bucket."
  type        = string
}

variable "eks_administrator" {
  description = "Administrator inputs reserved for the future EKS cluster; leave null until EKS access is configured."
  type = object({
    public_ipv4_cidr = string
    iam_role_arn     = string
  })
  default  = null
  nullable = true

  validation {
    condition = var.eks_administrator == null ? true : (
      can(cidrnetmask(var.eks_administrator.public_ipv4_cidr)) &&
      try(split("/", var.eks_administrator.public_ipv4_cidr)[1] == "32", false) &&
      try(cidrhost(var.eks_administrator.public_ipv4_cidr, 0) != "0.0.0.0", false)
    )
    error_message = "When set, public_ipv4_cidr must be a specific IPv4 /32, never 0.0.0.0/0."
  }

  validation {
    condition = var.eks_administrator == null ? true : can(regex(
      "^arn:aws:iam::${var.aws_account_id}:role/.+$",
      var.eks_administrator.iam_role_arn
    ))
    error_message = "When set, iam_role_arn must be an IAM role ARN in the configured AWS account."
  }
}