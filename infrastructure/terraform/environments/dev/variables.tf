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