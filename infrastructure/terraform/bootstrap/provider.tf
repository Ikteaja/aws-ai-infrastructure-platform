
# Credentials come from your signed-in AWS profile.
provider "aws" {
  region = "eu-central-1"

  # Prevent accidental deployment into another AWS account.
  allowed_account_ids = ["429496640190"]

  default_tags {
    tags = {
      Project   = "healthcare-operations-assistant"
      Component = "terraform-state"
      ManagedBy = "Terraform"
    }
  }
}