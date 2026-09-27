# Call our reusable document-storage module.
module "document_storage" {
  source = "../../modules/document-storage"

  # Pass the lab's bucket name into the module.
  bucket_name = var.document_bucket_name

  tags = {
    Project     = "healthcare-operations-assistant"
    Environment = "lab"
    ManagedBy   = "Terraform"
    DataType    = "synthetic"
  }
}