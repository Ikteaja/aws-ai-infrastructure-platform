# Terraform infrastructure

This directory contains reusable Terraform modules and environment-specific configurations for the AI infrastructure platform.

## Document storage lab

The `environments/lab` configuration creates a private S3 bucket through the `modules/document-storage` module. The bucket has public access blocked, bucket-owner-enforced ownership, default server-side encryption, and versioning enabled. The lab is intended for synthetic or otherwise approved documents, not patient records or production data.

### Prerequisites

- Terraform 1.1 or later.
- AWS credentials configured through the AWS CLI, environment variables, or another supported credential provider. Do not put credentials in Terraform files.
- A globally unique S3 bucket name that meets AWS naming rules.

### Initialize and review

From `infrastructure/terraform/environments/lab` in PowerShell:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars and choose a globally unique bucket name.
terraform init
terraform fmt -recursive
terraform validate
terraform plan
```

Review the plan before applying it. To create the lab bucket, run `terraform apply`. To remove it later, run `terraform destroy`. The bucket is not force-destroyed by default; remove its objects deliberately before destroying it.

Terraform state can contain infrastructure metadata and must be kept private. This lab uses Terraform's default local state; do not commit state files or the populated `terraform.tfvars` file.