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
  description = "Confirmed administrator inputs for the EKS cluster. Refresh the public /32 immediately before deployment."
  type = object({
    public_ipv4_cidr = string
    iam_role_arn     = string
  })
  nullable = false

  validation {
    condition = (
      can(cidrnetmask(var.eks_administrator.public_ipv4_cidr)) &&
      try(split("/", var.eks_administrator.public_ipv4_cidr)[1] == "32", false) &&
      try(cidrhost(var.eks_administrator.public_ipv4_cidr, 0) != "0.0.0.0", false)
    )
    error_message = "public_ipv4_cidr must be a specific IPv4 /32, never 0.0.0.0/0."
  }

  validation {
    condition = can(regex(
      "^arn:aws:iam::${var.aws_account_id}:role/.+$",
      var.eks_administrator.iam_role_arn
    ))
    error_message = "iam_role_arn must be an IAM role ARN in the configured AWS account."
  }
}

variable "eks_kubernetes_version" {
  description = "EKS Kubernetes version selected from AWS standard support; add-ons resolve to compatible releases."
  type        = string
  default     = "1.35"

  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.eks_kubernetes_version))
    error_message = "Set a Kubernetes minor version such as 1.35."
  }
}

variable "eks_cpu_instance_type" {
  description = "x86_64 EC2 instance type for the initial CPU node group."
  type        = string
  default     = "t3.medium"
}

variable "eks_node_min_size" {
  description = "Minimum number of On-Demand CPU worker nodes."
  type        = number
  default     = 1
}

variable "eks_node_desired_size" {
  description = "Initial desired number of On-Demand CPU worker nodes."
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of CPU worker nodes; automatic scaling is not enabled by this value."
  type        = number
  default     = 2
}