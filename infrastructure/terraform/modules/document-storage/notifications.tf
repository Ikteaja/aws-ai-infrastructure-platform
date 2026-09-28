# Send document-bucket events to Amazon EventBridge.
# Later, an EventBridge rule can route new-document events to ingestion.
resource "aws_s3_bucket_notification" "documents" {
  bucket = aws_s3_bucket.documents.id

  eventbridge = true
}