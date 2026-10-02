# URLs are used by Docker push and later by Kubernetes image references.
output "repository_urls" {
  description = "Repository URL indexed by application name."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

# ARNs identify the resources that publisher and EKS pull policies may access.
output "repository_arns" {
  description = "Repository ARN indexed by application name."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.arn }
}

output "kms_key_arn" {
  description = "Shared customer-managed ECR encryption key."
  value       = aws_kms_key.images.arn
}
