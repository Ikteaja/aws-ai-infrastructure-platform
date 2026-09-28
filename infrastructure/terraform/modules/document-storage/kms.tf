# Identify the AWS account running Terraform.
data "aws_caller_identity" "current" {}

# Create a customer-managed key for document encryption.
resource "aws_kms_key" "documents" {
  description = "Encryption key for ${var.bucket_name}"

  # Create a symmetric key for encryption and decryption.
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"

  # Automatically rotate the key material.
  enable_key_rotation = true

  # Allow a recovery period if deletion is scheduled.
  deletion_window_in_days = 30

  # Keep AWS's protection against accidentally locking out administrators.
  bypass_policy_lockout_safety_check = false

  # Enable this account to grant key access through IAM policies.
  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "EnableAccountIAMPermissions"
        Effect = "Allow"

        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }

        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  # Reuse the root module's tags and identify this specific resource.
  tags = merge(var.tags, {
    Name      = "${var.bucket_name}-key"
    Component = "document-encryption"
  })
}