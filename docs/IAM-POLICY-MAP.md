# IAM ownership, policy map and operating procedure

Account: `429496640190`. Region: `eu-central-1`. Inventory captured on 2026-10-03 using the `ai-lab-admin` SSO profile. The project builds secure document-based AI services; deployment access is separate from application and AWS service identities.

## Ownership boundaries

| Layer | Terraform root / state | Owns | Operator |
|---|---|---|---|
| Bootstrap | `infrastructure/terraform/bootstrap` / `bootstrap/terraform.tfstate` | State bucket, GitHub OIDC, deployment roles and their permissions, standalone network-read policy | Authorized administrator with temporary SSO credentials |
| After bootstrap | `infrastructure/terraform/environments/dev` / `dev/terraform.tfstate` | Document storage and KMS resource policies; network, Flow Logs role, publishing policy and log encryption | Existing GitHub plan and manually approved apply workflows |
| Future workloads | Environment modules, when implemented | Dedicated ingestion, API, EKS and model identities | Reviewed environment deployment |
| AWS-owned | Outside these Terraform states | Identity Center administrator and AWS service-linked roles | Identity Center / relevant AWS service |

Bootstrap remains an ongoing administrative layer: deployment permission changes belong here even after initial setup. Dev cannot update its own deployment role. Resource policies stay beside the resources they protect. Never import a resource into two states.

## Roles and policies

All abbreviated policy names below have the prefix `healthops-dev-`.

| Role | Trusted identity | Policies | Purpose / scope |
|---|---|---|---|
| `healthops-dev-terraform-plan-permissions` | GitHub OIDC, repository main and pull-request subjects | `terraform-plan-permissions` | Read dev state and document bucket settings; write/delete only the dev state lock |
| Same plan role | Same trust | `kms-plan` | Read document-key configuration, restricted by tags |
| Same plan role | Same trust | `cost-reporting` | `ce:GetCostAndUsage` account spending report |
| `healthops-dev-terraform-apply` | GitHub OIDC, repository main subject | `terraform-apply-permissions` | Update dev state and document bucket configuration |
| Same apply role | Same trust | `terraform-apply` | Document bucket notifications; not a duplicate of the preceding policy |
| Same apply role | Same trust | `kms-apply` | Create and configure tagged document encryption keys |
| Same apply role | Same trust | `network-apply` | Configure dev network, Flow Logs key/log group and the specific Flow Logs role; scoped `iam:PassRole` |
| `healthops-dev-vpc-flow-logs` | `vpc-flow-logs.amazonaws.com` | `vpc-flow-logs-publish` | Publish network metadata to the dedicated CloudWatch log group |
| No attachment | None | Managed policy `network-plan-read` | Existing network/key/log/Flow Logs role reads; imported as unattached, so it currently grants nothing |

No managed policies were attached to these three project roles at inventory time. Seven deployment inline policies and one workload inline policy existed. Exact addresses and import IDs: [iam-resource-map.json](iam-resource-map.json). Point-in-time evidence: [iam-adoption-baseline.json](iam-adoption-baseline.json), which contains IAM configuration, not credentials.

## Source of truth

- `bootstrap/*_role.tf`: deployment identity properties.
- `bootstrap/policies/plan/` and `bootstrap/policies/apply/`: live trust and inline permission documents consumed by Terraform.
- `bootstrap/managed_policies.tf` and `bootstrap/policies/managed/`: standalone managed policy.
- `bootstrap/github_oidc.tf`: shared GitHub provider.
- `bootstrap/imports.tf`: retained adoption declarations for 11 existing resources.
- `modules/network/flow-logs.tf`: workload role, publishing policy and KMS resource policy, already in dev state.
- `modules/document-storage/` and `bootstrap/state_bucket.tf`: S3/KMS resource policies, already Terraform-managed.
- `infrastructure/terraform/policies/`: future ECR proposals, **not deployed automatically**.

The three original export documents and four older policy/trust copies were
removed after confirming that their parsed JSON exactly matched the active
bootstrap documents. Edit only `bootstrap/policies/` for deployment permissions.
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
