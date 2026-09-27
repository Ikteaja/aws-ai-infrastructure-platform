# Display the bucket name for environment backend configuration.
output "state_bucket_name" {
  description = "S3 bucket used to store Terraform state."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_region" {
  description = "AWS region containing the state bucket."
  value       = "eu-central-1"
}