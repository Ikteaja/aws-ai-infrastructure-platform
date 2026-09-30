# Declare which provider this reusable module needs.
# Credentials and region come from the calling dev root module.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}