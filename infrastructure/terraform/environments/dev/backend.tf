# Development state is separate from bootstrap state.
terraform {
  backend "s3" {
    bucket = "healthops-tfstate-429496640190-eu-central-1"
    key    = "dev/terraform.tfstate"
    region = "eu-central-1"

    encrypt      = true
    use_lockfile = true
  }
}