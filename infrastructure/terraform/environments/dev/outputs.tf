# Display the bucket name after deployment.
output "document_bucket_name" {
  description = "Bucket used for hospital source documents."
  value       = module.document_storage.bucket_name
}

# Display the bucket identifier for later permissions configuration.
output "document_bucket_arn" {
  description = "ARN of the document bucket."
  value       = module.document_storage.bucket_arn
}

# Expose the child module's VPC ID to operators.
output "network_vpc_id" {
  description = "Development VPC ID."
  value       = module.network.vpc_id
}

# Display the private subnet IDs after deployment.
output "network_private_subnet_ids" {
  description = "Development private subnet IDs by subnet key."
  value       = module.network.private_subnet_ids
}

# Display route-table IDs for network verification.
output "network_private_route_table_ids" {
  description = "Development private route-table IDs by subnet key."
  value       = module.network.private_route_table_ids
}

output "ecr_repository_urls" {
  description = "ECR repository URLs indexed by repository name."
  value       = module.ecr.repository_urls
}

output "ecr_kms_key_arn" {
  description = "ARN of the customer-managed ECR encryption key."
  value       = module.ecr.kms_key_arn
}