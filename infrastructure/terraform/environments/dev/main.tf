# Call our reusable document-storage module.
module "document_storage" {
  source = "../../modules/document-storage"

  # Pass the lab's bucket name into the module.
  bucket_name = var.document_bucket_name
  
  # These tags must match the conditions in our AWS permissions.
  tags = {
    Project     = "healthcare-operations-assistant"
    Environment = "dev"
    ManagedBy   = "Terraform"
    DataType    = "synthetic"
  }
}