# The root module supplies the globally unique bucket name.
variable "bucket_name" {
  description = "Name of the S3 bucket used for source documents."
  type        = string
}

# Labels help identify ownership and purpose in AWS.
variable "tags" {
  description = "Tags applied to the document bucket."
  type        = map(string)
  default     = {}
}