variable "cluster_name" {
  description = "Name of the EKS cluster that already exists in the same root."
  type        = string

  validation {
    condition     = length(var.cluster_name) >= 1 && length(var.cluster_name) <= 100
    error_message = "Provide an EKS cluster name between 1 and 100 characters."
  }
}

variable "aws_account_id" {
  description = "AWS account ID that owns the EKS cluster."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Provide a 12-digit AWS account ID."
  }
}

variable "administrator_iam_role_arn" {
  description = "Explicit IAM role ARN receiving EKS cluster administrator access."
  type        = string

  validation {
    condition = can(regex(
      "^arn:aws:iam::${var.aws_account_id}:role/.+$",
      var.administrator_iam_role_arn
    ))
    error_message = "Provide an IAM role ARN in the same account as the EKS cluster."
  }
}
