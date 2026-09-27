# Configure where Terraform creates AWS resources.
# Credentials come from the selected AWS_PROFILE.
provider "aws" {
  region = var.aws_region

  # Stop if the credentials belong to a different account.
  allowed_account_ids = [var.aws_account_id]
}