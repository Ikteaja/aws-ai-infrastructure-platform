# Clean up unfinished uploads to avoid storing abandoned upload parts.
resource "aws_s3_bucket_lifecycle_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    # Apply this rule to all object names in the bucket.
    filter {}

    # Remove upload parts if an upload remains unfinished for seven days.
    # Completed documents and their previous versions are preserved.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}