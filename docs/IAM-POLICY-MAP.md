# IAM ownership, policy map and operating procedure

Account: `429496640190`. Region: `eu-central-1`. Inventory captured on 2026-10-03 using the `ai-lab-admin` SSO profile. The project builds secure document-based AI services; deployment access is separate from application and AWS service identities.

## Ownership boundaries

| Layer | Terraform root / state | Owns | Operator |
|---|---|---|---|
| Bootstrap | `infrastructure/terraform/bootstrap` / `bootstrap/terraform.tfstate` | State bucket, GitHub OIDC, deployment roles and their permissions, standalone network-read policy | Authorized administrator with temporary SSO credentials |
| After bootstrap | `infrastructure/terraform/environments/dev` / `dev/terraform.tfstate` | Document storage, ECR repositories and keys; network, Flow Logs role, publishing policy and log encryption; EKS cluster and managed node group when approved | Existing GitHub plan and manually approved apply workflows |
| Bootstrap-managed workload identities | `infrastructure/terraform/bootstrap` / `bootstrap/terraform.tfstate` | EKS control-plane, worker, VPC CNI, and administrator IAM roles and scoped Terraform policies | Authorized administrator with temporary SSO credentials |
| Future workloads | Environment modules, when implemented | Dedicated ingestion, API and model identities | Reviewed environment deployment |
| AWS-owned | Outside these Terraform states | Identity Center administrator and AWS service-linked roles | Identity Center / relevant AWS service |

Bootstrap remains an ongoing administrative layer: deployment permission changes belong here even after initial setup. Dev cannot update its own deployment role. Resource policies stay beside the resources they protect. Never import a resource into two states.

## Roles and policies

All abbreviated policy names below have the prefix `healthops-dev-`.

| Role | Trusted identity | Policies | Purpose / scope |
|---|---|---|---|
| `healthops-dev-terraform-plan-permissions` | GitHub OIDC, repository main and pull-request subjects | `terraform-plan-permissions` | Read dev state and document bucket settings; write/delete only the dev state lock |
| Same plan role | Same trust | `kms-plan` | Read document-key configuration, restricted by tags |
| Same plan role | Same trust | `ecr-plan` | Read the two dev repositories and tagged ECR key |
| Same plan role | Same trust | Managed `network-plan-read` | Read VPC, routes, gateways, endpoints, security groups, Flow Logs and network resource metadata for dev planning |
| Same plan role | Same trust | Managed `eks-plan-read` | Read only the `ai-platform-dev` cluster, CPU node group, add-ons, access entry, launch template, log group and named workload roles |
| Same plan role | Same trust | `cost-reporting` | `ce:GetCostAndUsage` account spending report |
| `healthops-dev-terraform-apply` | GitHub OIDC, repository main subject | `terraform-apply-permissions` | Update dev state and document bucket configuration |
| Same apply role | Same trust | `terraform-apply` | Document bucket notifications; not a duplicate of the preceding policy |
| Same apply role | Same trust | `kms-apply` | Create and configure tagged document encryption keys |
| Same apply role | Same trust | `ecr-apply` | Manage the tagged ECR key and two dev repositories |
| Same apply role | Same trust | `network-apply` | Configure dev network, read network resource metadata, Flow Logs key/log group and the specific Flow Logs role; scoped `iam:PassRole` |
| Same apply role | Same trust | Managed `network-egress-apply` | Manage the dev NAT, Internet Gateway, S3 gateway endpoint and EKS connectivity security groups |
| Same apply role | Same trust | Managed `eks-apply` | Manage only the named dev EKS cluster, CPU node group, add-ons, administrator association, log group and named launch template; scoped `iam:PassRole` |
| `healthops-dev-ecr-image-publisher` | GitHub OIDC, repository main subject only | `ecr-image-publisher` | Push and inspect images in only the two dev repositories |
| `healthops-dev-vpc-flow-logs` | `vpc-flow-logs.amazonaws.com` | `vpc-flow-logs-publish` | Publish network metadata to the dedicated CloudWatch log group |
| `healthops-dev-eks-admin` | Verified AWS IAM Identity Center SSO role ARN in `policies/eks-admin/trust.json` | No AWS permissions attached | Dedicated assumed identity for EKS Kubernetes administrator access; EKS authorization comes from the cluster access-policy association |
| `healthops-dev-eks-cluster` | `eks.amazonaws.com` | AWS-managed `AmazonEKSClusterPolicy` | Control-plane infrastructure operations |
| `healthops-dev-eks-workers` | `ec2.amazonaws.com` | AWS-managed `AmazonEKSWorkerNodePolicy` and `AmazonEC2ContainerRegistryPullOnly` | Worker registration and private ECR pulls |
| `healthops-dev-eks-vpc-cni` | `pods.eks.amazonaws.com`, limited to `ai-platform-dev` | AWS-managed `AmazonEKS_CNI_Policy` | Dedicated EKS Pod Identity for VPC CNI networking |

The adoption baseline is a point-in-time record: it showed the network read
managed policy as unattached. On 2026-10-06, a reviewed bootstrap apply created
the EKS service roles, EKS plan/apply managed policies, and their attachments
(11 added, 0 changed, 0 destroyed). A live IAM query confirmed
`healthops-dev-eks-plan-read` is attached to the Terraform plan role; IAM policy
simulation allowed `iam:GetRole` on the three EKS service roles and
`eks:DescribeAddonVersions` in `eu-central-1`. Exact adopted
addresses and import IDs: [iam-resource-map.json](iam-resource-map.json).
Point-in-time IAM evidence: [iam-adoption-baseline.json](iam-adoption-baseline.json);
it contains no credentials.

The ECR plan/apply policies and image-publisher role are declared in bootstrap
Terraform. The EKS policy and service-role changes above are applied; other
bootstrap changes must be checked against their actual live state before
assuming they are deployed. The publisher role is separate from the Terraform
apply role and cannot manage KMS.

The EKS administrator role is a separately existing role with a trust
relationship restricted to the exact SSO role verified in account
`429496640190`. The AWS-owned SSO role remains outside this
Terraform state. That SSO role has the AWS-managed
`AdministratorAccess` policy; IAM simulation confirmed `sts:AssumeRole` is
allowed for the proposed EKS role ARN. We do not manage the AWS-owned SSO role
through this Terraform state. The dedicated role intentionally has no broad AWS
permissions: after a cluster exists, the EKS access entry associates
`AmazonEKSClusterAdminPolicy` at cluster scope.

## Source of truth

- `bootstrap/*_role.tf`: deployment identity properties.
- `bootstrap/policies/plan/`, `bootstrap/policies/apply/` and `bootstrap/policies/publisher/`: trust and inline permission documents consumed by Terraform.
- `bootstrap/policies/managed/`: scoped network plan-read and egress-apply managed policy documents.
- `bootstrap/managed_policies.tf` and `bootstrap/policies/managed/`: standalone managed policy.
- `bootstrap/github_oidc.tf`: shared GitHub provider.
- `bootstrap/imports.tf`: retained adoption declarations for 11 existing resources.
- `modules/network/flow-logs.tf`: workload role, publishing policy and KMS resource policy, already in dev state.
- `modules/document-storage/` and `bootstrap/state_bucket.tf`: S3/KMS resource policies, already Terraform-managed.
- `infrastructure/terraform/policies/README.md`: points to bootstrap-managed policy sources; do not create duplicate managed policies.

The ECR and network policies are maintained under `bootstrap/policies/`; update
the policy source files and managed-policy resources together when changing
deployment permissions.
The adoption baseline remains a historical audit record, not a deployment source.

The aliased IAM provider has no default tags, preventing state-bucket tags from silently changing imported identities. Existing tags are preserved. Roles and OIDC have Terraform deletion guards; these do not restrict AWS console actions.

## Adoption record

On 2026-10-03 the import plan passed `scripts/check_iam_import_plan.py`, which rejects live mutations, unexpected imports and missing imports. Applying that exact saved plan completed successfully: **11 imported, 0 added, 0 changed, 0 destroyed**.

A subsequent live bootstrap plan returned exit code 0: **No changes. Your infrastructure matches the configuration.**

A fresh post-import AWS inventory also matched the reviewed adoption baseline.
The import/drift guard suite passed all seven tests, and bootstrap validation passed.

The existing Flow Logs role and publishing policy were verified in dev state and were not imported again. S3/KMS resource policies are properties of their resources, not standalone IAM policies.

AWS-owned roles were inventoried and excluded: `AWSReservedSSO_AdministratorAccess_4af4e9b42a20d275`, `AWSServiceRoleForOrganizations`, `AWSServiceRoleForResourceExplorer`, `AWSServiceRoleForSSO`, `AWSServiceRoleForSupport`, and `AWSServiceRoleForTrustedAdvisor`.

## Findings for separate reviewed changes

1. The network-read managed policy is unattached. The plan role's three current policies do not grant required EC2/Flow Logs reads. Review required reads, then explicitly attach the policy in bootstrap before expecting dev planning to work.
2. Apply-role `Name` and `Component` tags incorrectly say `terraform-plan`; deployment roles/OIDC retain manual ownership tags. These were preserved during adoption. Correct them through a reviewed plan.
3. Networking, including Flow Logs, is already deployed and in dev state, despite earlier README deployment-verification notes.
4. ECR proposals exist, but dev does not call the ECR module and neither deployment role has ECR-specific policies. Grant permissions with the reviewed feature, not preemptively.
5. Existing `s3:Get*` reads and region-wide network permissions deserve a separate least-privilege review. Adoption does not certify those permissions.
6. Trust subjects include owner/repository IDs (`Ikteaja@56071290` and repository `@1361265436`). Preserve the actual token format rather than substituting conventional example subjects.

During verification, the ignored local dev `terraform.tfvars` still named an
example bucket. It was corrected to `healthops-dev-documents-429496640190`, matching
AWS and CI. The replacement plan caused by the old value was never applied.
After correction, a fresh live dev plan also reported **no changes**.

## Controlled policy automation

Terraform now creates/updates policies from versioned JSON. Review policy, trust, attachment and mapping changes in a PR. Bootstrap changes use administrator credentials; existing dev workflows handle workload deployment only. Do not grant dev roles permission to change deployment identities or bootstrap state.

From the repository root in PowerShell:

```powershell
$env:AWS_PROFILE = 'ai-lab-admin'
aws sts get-caller-identity
New-Item -ItemType Directory -Force .local/iam
terraform '-chdir=infrastructure/terraform/bootstrap' init -lockfile=readonly
terraform '-chdir=infrastructure/terraform/bootstrap' validate
terraform '-chdir=infrastructure/terraform/bootstrap' plan '-out=../../../.local/iam/reviewed.tfplan'
terraform '-chdir=infrastructure/terraform/bootstrap' show '../../../.local/iam/reviewed.tfplan'
# Only after reviewing the exact saved plan:
terraform '-chdir=infrastructure/terraform/bootstrap' apply '../../../.local/iam/reviewed.tfplan'
```

Saved plans and operational inventories stay outside Git. Avoid blanket `-auto-approve` for policy changes. The import-plan guard is for the initial adoption only; it deliberately rejects subsequent permission edits or an already-imported no-change plan.

## Monitoring and records

```powershell
$env:AWS_PROFILE = 'ai-lab-admin'
python scripts/iam_inventory.py --output .local/iam/current.json --baseline docs/iam-adoption-baseline.json
terraform '-chdir=infrastructure/terraform/bootstrap' plan -detailed-exitcode
```

Inventory exits 2 for missing/unexpected project roles or changed trust, tags, boundaries, inline policies, managed attachments, managed-policy documents or GitHub OIDC settings. API errors also fail the command. Scope is `healthops-` roles/customer-managed policies and the GitHub provider; it is not an account-wide security audit. Terraform plans for both roots also check resource-policy drift. Inventory catches extra unmanaged policies/attachments that a no-change Terraform plan can miss.

The adoption baseline is an immutable historical record. After an approved IAM change, save a new reviewed baseline and change the monitor baseline path. Preserve the prior snapshot and record commit, operator, date, plan result and reason; never automatically accept live drift.

CI validates bootstrap and tests the import/drift guards without AWS credentials.
`terraform-plan.yml` calls the reusable `iam-checks.yml`; both the development
plan and final `Terraform review gate` require successful IAM checks. Failed,
cancelled or skipped checks block the gate. The IAM workflow can also run manually.
The apply workflow accepts only a successful complete Terraform Plan run, so its
existing saved-plan approval process includes the IAM check result.

This validates configuration and guard code; it does not perform a live bootstrap
plan or certify least-privilege policy contents. Bootstrap changes still require
the administrator's reviewed local plan/apply procedure. No bootstrap AWS write
credentials are exposed to PR jobs. Require `Terraform review gate` in repository
branch protection/rulesets; workflow code alone cannot enforce the merge button.

Scheduled AWS monitoring is not enabled: run the inventory with administrator SSO until a dedicated read-only audit identity and notification destination are configured. Existing dev roles cannot read the entire bootstrap inventory and should not become administrators for monitoring.

Correlate STS sessions and IAM changes with AWS CloudTrail during investigations. This migration does not establish a persistent CloudTrail trail or alert delivery.

The adoption approach follows [HashiCorp import guidance](https://developer.hashicorp.com/terraform/language/import): declare ownership, review an import-only plan, apply, then verify a no-change plan.
