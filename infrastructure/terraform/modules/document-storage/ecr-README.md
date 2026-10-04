# ECR module: private container image storage

## Goal

Create a secure place in AWS to store the API and mock-model Docker images.
Amazon Elastic Container Registry (ECR) stores images; it does not run applications.
Amazon EKS will later pull these images and run them as containers.

For example, the image for commit `abc123` is uploaded once to `healthops-dev/api:abc123`.
The deployment can then reference its immutable image digest. The mock service has
its own repository so the two applications can be released independently.

**This milestone creates repositories, encryption and cleanup configuration.
It does not create EKS, publish images automatically, or change the network.**

## What this module creates

| Resource | Dev configuration | Purpose |
|---|---|---|
| Private API repository | `healthops-dev/api` | Stores API image versions |
| Private mock repository | `healthops-dev/mock-model` | Stores mock image versions |
| Shared customer-managed KMS key | Tag `Name=healthops-dev-ecr-key` | Encrypts both repositories; rotation enabled |
| Two lifecycle policies | Untagged images expire after 14 days | Removes eligible untagged images |
| Immutable image tags | Both repositories | Prevents an existing tag from being overwritten |
| Scan on push | Both repositories | Requests vulnerability scanning after upload |

Default resource count: **5 managed resources**: two repositories, two lifecycle policies,
one KMS key. AWS also manages service grants for ECR's use of the key.
The caller identity and partition are data lookups, not infrastructure resources.

All repositories carry `Project`, `Environment`, `ManagedBy`, `Owner`, `Name`,
`Component` and `Service` tags. The key carries the same shared tags without `Service`.
No public or cross-account repository policy is created. IAM still controls access.

## Workflow and responsibility mapping

```mermaid
flowchart TD
    Dev["Developer: code and Dockerfiles"] --> CI["Application CI: tests, build, Trivy"]
    CI --> Publish["Future publisher job: GitHub OIDC"]
    Publish --> API["Private ECR: API images"]
    Publish --> Mock["Private ECR: mock images"]
    TF["Terraform dev root"] --> Module["ECR module: repositories and lifecycle policies"]
    Module --> API
    Module --> Mock
    Key["Shared rotating KMS key"] --> API
    Key --> Mock
    API --> Pull["Future EKS node role and network path"]
    Mock --> Pull
    Pull --> Pods["API and mock Kubernetes pods"]
```

| Layer | Configured here? | Responsibility |
|---|---|---|
| Dev Terraform root | Integration snippets | Calls `module.ecr`; supplies naming and tags |
| AWS provider | Already in dev root | Region, credentials and account guard |
| ECR module | Yes | Image storage, encryption, scan-on-push and lifecycle |
| Terraform plan role | Supplementary policy supplied | Reads repository/key configuration |
| Terraform apply role | Supplementary policy supplied | Manages the module's AWS resources |
| Image publisher | Next milestone | Pushes tested images using separate scoped permissions |
| EKS pull identity | Later | Authorizes nodes to download the images |
| Network module | Existing, independent | Subnets and routing; not passed to ECR |

A child `required_providers` block declares a dependency. It does not duplicate the
root's provider configuration. Do not put an AWS profile or credentials inside this module.

Your existing private subnets have no NAT gateway or VPC endpoints. Creating ECR
will not make them able to pull images. Before EKS, choose an outbound path or the
required private endpoints, including ECR API, ECR Docker and S3 for image layers,
plus other endpoints needed by the cluster. Interface endpoints and NAT can add costs.

## Files and their purpose

| File | Function |
|---|---|
| `versions.tf` | Declares Terraform and AWS provider requirements |
| `variables.tf` | Validates repository names, retention and input tags |
| `kms.tf` | Creates the shared rotating encryption key |
| `main.tf` | Creates private repositories with immutable tags and scanning |
| `lifecycle.tf` | Defines cleanup of old untagged images |
| `outputs.tf` | Returns repository URLs, ARNs and the encryption key ARN |
| `README.md` | Explains setup, use, costs and cleanup |

The bundle also includes `integration/*.tf.example` and scoped IAM policy documents.
The `.example` files are instructions to append configuration, not complete root modules.

## Security and cost choices

- **KMS:** One customer-managed key is shared across both repositories. AWS lists a
  base charge of USD 1 per key-month, prorated, plus applicable requests. Rotation
  can add charges for retained rotated key material. This is an additional key beyond
  the existing document and flow-log keys.
- **Lower-cost alternative:** ECR's default AES-256 encryption is encrypted at rest
  without a customer-managed key fee. This implementation uses a CMK to fit the
  project's existing security scans. If you prefer AES-256, change the design and
  explicitly review relevant scanner policies **before creating the repositories**.
  ECR repository encryption cannot be changed in place afterward.
- **Storage:** Stored image data incurs ECR storage charges. Avoid pushing every
  local experiment. No GPU, EC2 worker, NAT gateway or endpoint is created here.
- **Scanning:** Check the registry scan type before deployment. Basic scanning has no
  additional scan charge; enhanced scanning uses Amazon Inspector pricing. This
  module does not overwrite account-wide scanning settings. Enhanced settings can
  change the effective scanning behavior. Keep the existing Trivy blocking CI checks.
- **Retention:** Only untagged images expire automatically, based on push age. Tagged
  images accumulate and therefore cost money. Maintain a release-retention process.
  ECR does not know which digests Kubernetes is using: keep a tag on deployed and
  rollback images, and preview lifecycle effects before removing tags.
- **Deletion:** `force_delete=false` prevents Terraform from deleting a nonempty
  repository. It does not prevent lifecycle expiration or authorized manual image deletion.

Official references:
- [ECR pricing](https://aws.amazon.com/ecr/pricing/)
- [KMS pricing](https://aws.amazon.com/kms/pricing/)
- [ECR encryption and required KMS permissions](https://docs.aws.amazon.com/AmazonECR/latest/userguide/encryption-at-rest.html)
- [ECR basic scanning](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning-basic.html)
- [Lifecycle policies](https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html)

## Step 1 — Start a branch from current main

Run PowerShell from your existing repository. If `git status` shows uncommitted work,
finish or save it before switching branches.

```powershell
Set-Location C:\Users\iktea\.vscode\aws-ai-infrastructure-platform
git status
git switch main
git pull --ff-only origin main
git switch -c feature/dev-ecr
```

## Step 2 — Copy the module and integrate the dev root

Extract `ecr-module.zip` into a temporary folder and open its `ecr-module` folder.
Copy its `infrastructure` contents into
this repository, preserving the existing Terraform files. It adds the module and
bootstrap-managed ECR permissions; it does not replace network or storage code.

1. Append `integration/dev-main.tf.example` to `infrastructure/terraform/environments/dev/main.tf`.
2. Append `integration/dev-outputs.tf.example` to that directory's `outputs.tf`.
3. Keep the existing `document_storage` and `network` module calls.
4. Keep the existing provider, backend and `.terraform.lock.hcl`.

The call uses `source = "../../modules/ecr"`. The repositories become:

```text
429496640190.dkr.ecr.eu-central-1.amazonaws.com/healthops-dev/api
429496640190.dkr.ecr.eu-central-1.amazonaws.com/healthops-dev/mock-model
```

## Step 3 — Apply bootstrap IAM permissions

The bootstrap root manages the scoped Terraform plan/apply policies and a separate
image-publisher role. The publisher trust is restricted to this repository's
`main` branch. Apply the reviewed bootstrap change with administrator credentials;
do not create or attach duplicate managed policies.

```powershell
Set-Location C:\Users\iktea\.vscode\aws-ai-infrastructure-platform
aws sso login --profile ai-lab-admin
$env:AWS_PROFILE = "ai-lab-admin"
aws sts get-caller-identity
terraform -chdir=infrastructure/terraform/bootstrap init -lockfile=readonly
terraform -chdir=infrastructure/terraform/bootstrap validate
terraform -chdir=infrastructure/terraform/bootstrap plan
# Apply only after reviewing the bootstrap plan.
terraform -chdir=infrastructure/terraform/bootstrap apply
```

After applying bootstrap, read and keep the publisher role ARN:

```powershell
$publisherRoleArn = terraform -chdir=infrastructure/terraform/bootstrap output -raw ecr_image_publisher_role_arn
if ($LASTEXITCODE -ne 0) { throw "Could not read the publisher role ARN from bootstrap state." }
```

Wait to configure the GitHub variable until the dev apply has created and verified
the repositories (Step 7 below). This keeps the first application CI merge from
attempting to push before ECR exists.

Do not store AWS access keys. The publisher policy allows authorization-token
retrieval and push/digest-read actions only for the two dev repositories; it cannot
administer ECR repositories or KMS keys.

## Step 4 — Initialize, validate and scan locally

All commands below start from the **repository root**, not the dev directory.

```powershell
Set-Location (git rev-parse --show-toplevel)
$env:AWS_PROFILE = "ai-lab-admin"
$env:AWS_REGION = "eu-central-1"

# Inspect effective scanning before assuming there are no enhanced-scan charges.
aws ecr get-registry-scanning-configuration --region eu-central-1 --profile ai-lab-admin

terraform fmt -recursive infrastructure/terraform
terraform -chdir=infrastructure/terraform/environments/dev init -lockfile=readonly
terraform -chdir=infrastructure/terraform/environments/dev validate

# Use the Python environment that actually contains Checkov on your machine.
$checkovPython = "$env:LOCALAPPDATA\healthops-tools\checkov\Scripts\python.exe"
$checkovLauncher = "$env:LOCALAPPDATA\healthops-tools\checkov\Scripts\checkov"
& $checkovPython $checkovLauncher `
  --directory infrastructure/terraform/environments/dev `
  --framework terraform --download-external-modules true --compact
if ($LASTEXITCODE -ne 0) { throw "Checkov failed; review findings before proceeding." }
```

Stop on any failed command. Do not suppress scan findings just to get a green run.
The pipeline still runs Trivy and Checkov across the complete dev configuration.

## Step 5 — Review the local plan, then push

```powershell
terraform -chdir=infrastructure/terraform/environments/dev plan `
  -var="aws_account_id=429496640190" `
  -var="document_bucket_name=healthops-dev-documents-429496640190" `
  -lock-timeout=5m

# Stage the module, bootstrap permissions, publishing workflow and dev integration.
git add infrastructure/terraform/modules/ecr `
  infrastructure/terraform/bootstrap `
  .github/workflows/ai-app-ci.yml `
  infrastructure/terraform/policies/README.md `
  infrastructure/terraform/environments/dev/main.tf `
  infrastructure/terraform/environments/dev/outputs.tf
git diff --cached --stat
git commit -m "Add private ECR repositories for API and mock model"
git push --set-upstream origin feature/dev-ecr
```

Expect five additions for this module if nothing else has changed. Investigate any
changes to existing storage/network resources. Do not commit state, `.terraform`,
binary plan files or AWS credentials.

## Step 6 — Use the existing review and manual-apply workflow

1. Open a pull request into `main`.
2. Review formatting, validation, both security scans, the PR plan and recorded AWS costs.
3. Merge only after successful checks. On a private GitHub Free repository, do not
   assume a green review gate automatically enforces merge protection.
4. Review the new **main-branch** plan. The PR plan is not an apply artifact.
5. Run the existing manual apply workflow with its required confirmation and current main plan run ID.
6. If an apply partially fails, fix the issue and generate a fresh plan before applying again.

This module does not alter the workflows or remove the approval step. Recorded Cost
Explorer spending is historical; it does not estimate the cost of these additions.

## Step 7 — Verify after apply

```powershell
terraform -chdir=infrastructure/terraform/environments/dev output -json ecr_repository_urls
aws ecr describe-repositories `
  --repository-names healthops-dev/api healthops-dev/mock-model `
  --region eu-central-1 --profile ai-lab-admin `
  --query "repositories[].{Name:repositoryName,URI:repositoryUri,Tags:imageTagMutability,Encryption:encryptionConfiguration.encryptionType,Scan:imageScanningConfiguration.scanOnPush}" `
  --output table
aws ecr get-lifecycle-policy --repository-name healthops-dev/api `
  --region eu-central-1 --profile ai-lab-admin
```

Verify both repositories are `IMMUTABLE`, encryption is `KMS`, the lifecycle policy
is present, and the effective registry scanning setup matches the intended basic scan.
A subsequent Terraform plan should show no changes.

## Step 8 — Publish and verify images

Application CI runs tests, builds from both Dockerfiles, blocks fixable HIGH/CRITICAL
Trivy findings, and exercises the two containers together. On a successful push to
`main`, a separate dependent job loads the exact tested images, assumes the dedicated
publisher role through GitHub OIDC, verifies both repositories, and pushes images
tagged with the full commit SHA. Pull-request runs never publish. If that immutable
tag already exists on a workflow rerun, the workflow reuses it and reports its digest
rather than trying to overwrite it.

Before merging the workflow changes or pushing any new commit to `main`, confirm
the GitHub repository variable `ECR_PUBLISHER_ROLE_ARN` is set; otherwise the
main-branch CI run will fail at its publisher configuration check. After the
first successful run, inspect the Application CI summary for both immutable image
digests. For a local AWS-side check:

```powershell
aws sso login --profile ai-lab-admin
$env:AWS_PROFILE = "ai-lab-admin"
aws ecr describe-images --repository-name healthops-dev/api --region eu-central-1 `
  --query "imageDetails[].{Tags:imageTags,Digest:imageDigest}" --output table
aws ecr describe-images --repository-name healthops-dev/mock-model --region eu-central-1 `
  --query "imageDetails[].{Tags:imageTags,Digest:imageDigest}" --output table
```

Use the reported `repository@sha256:...` digest for later deployment. ECR scan-on-push
is asynchronous and complements, rather than replaces, the blocking Trivy checks.

## Cleanup and troubleshooting

| Symptom | What to check |
|---|---|
| `kms:TagResource` denied | Apply policy attached; Name/Project/Environment/Component match the module |
| `kms:CreateGrant` denied | Apply role's grant permission and key policy; do not revoke ECR service grants |
| Repository already exists | Inspect ownership; import only if this Terraform state should manage it |
| Immutable tag already exists | Reuse the verified image or publish a distinct build tag |
| Empty repository has no scan results | Push an image; scans apply to images, not an empty repository |
| EKS image pull fails later | Check repository/image, node IAM and subnet connectivity separately |
| `RepositoryNotEmptyException` | Review and explicitly remove images before repository destruction |

Never run an unreviewed `terraform destroy` from dev: its state also contains the
network and document storage. A teardown needs its own reviewed plan and approval.
Retain deployed and rollback images until they are no longer needed. Delete the
repositories before scheduling deletion of their encryption key. KMS deletion has
a 30-day recovery window here; do not disable or delete a key still used by ECR.

## Completion checklist

- [ ] Module and root integration committed.
- [ ] Bootstrap plan/apply and publisher IAM changes reviewed and applied.
- [ ] Local validation and security scans pass.
- [ ] PR and main plans reviewed; no unexpected changes.
- [ ] Manual apply completed and both repositories verified.
- [ ] `ECR_PUBLISHER_ROLE_ARN` repository variable is configured.
- [ ] Successful main-branch CI published both images and recorded their digests.
