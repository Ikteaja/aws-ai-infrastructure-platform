# Display the bucket name for environment backend configuration.
output "state_bucket_name" {
  description = "S3 bucket used to store Terraform state."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_region" {
  description = "AWS region containing the state bucket."
  value       = "eu-central-1"
}

output "ecr_image_publisher_role_arn" {
  description = "OIDC role ARN for publishing application images to the dev ECR repositories."
  value       = aws_iam_role.ecr_image_publisher.arn
}

output "eks_admin_role_arn" {
  description = "Dedicated IAM role prepared for HealthOps dev EKS cluster administrator access."
  value       = aws_iam_role.eks_admin.arn
}