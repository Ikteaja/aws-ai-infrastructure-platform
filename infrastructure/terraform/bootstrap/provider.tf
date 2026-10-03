
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

# Preserve existing IAM tags during adoption. State-bucket default tags must
# not silently rewrite shared identities or imported policies.
provider "aws" {
  alias               = "iam"
  region              = "eu-central-1"
  allowed_account_ids = ["429496640190"]
}
