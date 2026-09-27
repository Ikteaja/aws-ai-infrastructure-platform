# Declare which provider this module uses.
# The root module supplies the AWS connection settings.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}