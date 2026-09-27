# Store the bootstrap infrastructure state in S3.
terraform {
  backend "s3" {
    bucket = "healthops-tfstate-429496640190-eu-central-1"
    key    = "bootstrap/terraform.tfstate"
    region = "eu-central-1"

    # Encrypt stored state and enable state locking.
    encrypt      = true
    use_lockfile = true
  }
}