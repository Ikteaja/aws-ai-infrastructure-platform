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