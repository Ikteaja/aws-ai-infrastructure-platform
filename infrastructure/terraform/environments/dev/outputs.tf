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

output "network_public_subnet_ids" {
  description = "Development public subnet IDs indexed by subnet key."
  value       = module.network.public_subnet_ids
}

output "network_nat_gateway_id" {
  description = "ID of the single lab NAT gateway."
  value       = module.network.nat_gateway_id
}

output "network_s3_gateway_endpoint_id" {
  description = "ID of the S3 gateway endpoint."
  value       = module.network.s3_gateway_endpoint_id
}

output "eks_control_plane_security_group_id" {
  description = "Additional security group prepared for the future EKS control plane."
  value       = module.network.eks_control_plane_security_group_id
}

output "eks_worker_security_group_id" {
  description = "Security group prepared for future EKS worker nodes."
  value       = module.network.eks_worker_security_group_id
}

output "ecr_repository_urls" {
  description = "ECR repository URLs indexed by repository name."
  value       = module.ecr.repository_urls
}

output "ecr_kms_key_arn" {
  description = "ARN of the customer-managed ECR encryption key."
  value       = module.ecr.kms_key_arn
}