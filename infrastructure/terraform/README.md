# Terraform infrastructure

This directory contains reusable modules and separate administrative and workload Terraform roots.

## State and policy ownership

| Root | Owns | S3 state key |
|---|---|---|
| `bootstrap/` | State bucket, GitHub OIDC, deployment roles and policies | `bootstrap/terraform.tfstate` |
| `environments/dev/` | Document storage, ECR repositories and KMS, networking and Flow Logs workload identity | `dev/terraform.tfstate` |

Deployment permissions remain in bootstrap after initial setup. Workload identities and resource policies stay in their environment modules. The dev root provisions two ECR repositories and their shared KMS key. The lab is for synthetic or approved documents only.

See the [IAM policy map](../../docs/IAM-POLICY-MAP.md) for every role and policy, import records, monitoring and the controlled change procedure. Files in `policies/` are historical references or future proposals; active deployment policies are under `bootstrap/policies/`.

### Prerequisites

- Terraform 1.16.x and the committed AWS provider lock files.
- AWS credentials configured through the AWS CLI, environment variables, or another supported credential provider. Do not put credentials in Terraform files.
- A globally unique S3 bucket name that meets AWS naming rules.

### Initialize and review

From `infrastructure/terraform/environments/dev` in PowerShell:

```powershell
$env:TF_VAR_aws_account_id = '429496640190'
$env:TF_VAR_aws_region = 'eu-central-1'
$env:TF_VAR_document_bucket_name = 'healthops-dev-documents-429496640190'
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=reviewed.tfplan
```

Local `terraform.tfvars` values override environment variables. Ensure any local
file matches the account and bucket above; an old example bucket name can propose
replacement of the deployed document bucket.

Review a saved plan before applying it. Bootstrap administration uses temporary SSO credentials; GitHub uses separate dev plan/apply roles. Normal dev deployments use the existing manually requested saved-plan apply workflow. Never destroy bootstrap as part of workload cleanup.

After a successful GitHub apply, the workflow summary lists every resource in
Terraform state, key resource identifiers and the result of a refresh-only check
against AWS.

### Verify a local apply

From the repository root in PowerShell, configure AWS credentials for the
Terraform apply role or an authorized administrator, then run:

```powershell
terraform -chdir=infrastructure/terraform/environments/dev state list
terraform -chdir=infrastructure/terraform/environments/dev output
terraform -chdir=infrastructure/terraform/environments/dev plan -refresh-only -detailed-exitcode
```

The refresh-only plan compares Terraform state with live AWS resources without
changing them. Exit code `0` means no differences; `2` means Terraform detected
differences that need review; `1` means the command failed. To verify ECR directly:

```powershell
aws ecr describe-repositories `
  --repository-names healthops-dev/api healthops-dev/mock-model `
  --region eu-central-1 --profile ai-lab-admin `
  --query "repositories[].{Name:repositoryName,URI:repositoryUri,Encryption:encryptionConfiguration.encryptionType}" `
  --output table
```

Both roots use separate S3 state keys and native locking. State can contain sensitive metadata; never commit state, saved plans, credentials or populated tfvars.
