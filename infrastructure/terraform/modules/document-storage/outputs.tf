# Return the bucket name to the calling root module.
output "bucket_name" {
  description = "Name of the document bucket."
  value       = aws_s3_bucket.documents.id
}

# Return the bucket's AWS resource identifier.
output "bucket_arn" {
  description = "ARN of the document bucket."
  value       = aws_s3_bucket.documents.arn
}

# Return the key ARN for future application permissions.
output "kms_key_arn" {
  description = "ARN of the customer-managed document encryption key."
  value       = aws_kms_key.documents.arn
}