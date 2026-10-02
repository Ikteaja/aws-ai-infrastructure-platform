# Identify the caller so the account can administer the encryption key through IAM.
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# One customer-managed key serves both repositories; it has a recurring KMS charge.
resource "aws_kms_key" "images" {
  description                        = "Container image encryption for ${var.name_prefix}"
  key_usage                          = "ENCRYPT_DECRYPT"
  customer_master_key_spec           = "SYMMETRIC_DEFAULT"
  enable_key_rotation                = true
  deletion_window_in_days            = 30
  bypass_policy_lockout_safety_check = false

  # This account principal enables IAM delegation; it does not grant every user access.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnableAccountIAMPermissions"
      Effect    = "Allow"
      Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}-ecr-key"
    Component = "container-registry"
  })
}
