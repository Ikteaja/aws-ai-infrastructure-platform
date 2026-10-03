# Terraform pull-request planning and cost reporting

> Historical workflow setup notes. Deployment roles and policies are now managed
> by Terraform bootstrap. Follow [IAM-POLICY-MAP.md](IAM-POLICY-MAP.md) for current
> ownership and permission changes instead of the manual IAM update commands below.
> The current workflow reports recorded Cost Explorer spending; older Infracost
> instructions here do not describe the active workflow.

Prepared for Ikteaja/aws-ai-infrastructure-platform on 30 September 2026.

## 1. What changes

The replacement `.github/workflows/terraform-plan.yml` runs:

1. Formatting, validation, Trivy and Checkov.
2. AWS-connected Terraform planning for owner-authored same-repository pull requests, main pushes and main manual runs.
3. Estimated monthly costs for the proposed dev configuration using the saved Terraform plan JSON.
4. Recorded account-wide AWS costs for the current UTC month through yesterday. On the first day of a month it reports the previous month.
5. A final `Terraform review gate` that fails if either job fails, is cancelled or is skipped.

It does not automatically merge or apply. Keep your supplied `terraform-apply.yml` unchanged: it already rejects PR runs, checks main/commit/freshness, and requires manual approval. The supplied apply summary references `steps.verify.outputs` correctly.

After merging, a fresh main plan is needed. Apply uses the main artifact `terraform-dev-RUN_ID-ATTEMPT`. PRs publish only review text under `terraform-pr-review-RUN_ID-ATTEMPT`, with no binary plan. Both include cost reports where relevant. Retention stays one day.

## 2. Merge enforcement limitation

A workflow can fail, but it does not control the Merge button by itself. Private personal repositories need GitHub Pro for protected branches; Free does not enforce this requirement. On Free, manually wait for the final gate. Do not call that an enforced merge control.

If using Pro, configure a main-branch protection rule requiring a pull request, `Terraform review gate`, and the application CI check as appropriate. Require up-to-date branches and include administrators/no bypass where offered. Let the checks run once so GitHub lists them. Avoid auto-merge until this behavior is verified.

Reference: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches

## 3. Place the files

The ZIP has these repository-relative paths:

- `.github/workflows/terraform-plan.yml`: replace the existing plan workflow.
- `infrastructure/terraform/bootstrap/policies/plan/trust.json`: reviewed planning-role trust policy.
- `infrastructure/terraform/bootstrap/policies/plan/healthops-dev-cost-reporting.json`: additional inline permission policy.
- `docs/terraform-pr-costs.md`: these instructions.

Use your current feature branch or create a workflow branch from it if it contains the pending network changes. Check `git status` before extracting into the repository and review the workflow diff afterwards. Do not overwrite unrelated uncommitted changes. Do not create a second planning workflow with a different filename.

## 4. Repository variables and secret

Under Settings → Secrets and variables → Actions:

| Type | Name | Value |
|---|---|---|
| Variable | TF_PLAN_ROLE_ARN | arn:aws:iam::429496640190:role/healthops-dev-terraform-plan-permissions |
| Variable | TF_APPLY_ROLE_ARN | Existing apply-role ARN; unchanged |
| Variable | TF_APPROVER | Ikteaja (exact capitalization for this workflow's PR check) |
| Secret | INFRACOST_API_KEY | Infracost API key for classic CLI 0.10.x |

The workflow pins Checkov 3.3.21 and the classic Infracost CLI 0.10.43, using `breakdown`. This avoids mixing newer `scan` CLI instructions with classic setup/authentication. The setup action is pinned to its resolved v3 commit. Existing Terraform and action versions are retained except the plan AWS authentication action uses the same pinned commit already in your apply workflow.

Local Infracost installation is optional for scanning in CI, but the following provides a way to obtain an API key without administrator rights.

### Optional Windows installation to obtain the key

Run in PowerShell:

```powershell
# Install the same classic CLI used by the workflow into a user directory.
$infracostDir = Join-Path $env:LOCALAPPDATA "healthops-tools\infracost"
New-Item -ItemType Directory -Force $infracostDir | Out-Null
$releaseUrl = "https://github.com/infracost/infracost/releases/download/v0.10.43"
$archive = Join-Path $infracostDir "infracost-windows-amd64.zip"
$checksumFile = "$archive.sha256"

Invoke-WebRequest "$releaseUrl/infracost-windows-amd64.zip" -OutFile $archive
Invoke-WebRequest "$releaseUrl/infracost-windows-amd64.zip.sha256" -OutFile $checksumFile

# Verify the archive before extracting or executing it.
$expected = ((Get-Content $checksumFile -Raw).Trim() -split '\s+')[0]
$actual = (Get-FileHash $archive -Algorithm SHA256).Hash
if ($actual -ine $expected) { throw "Infracost checksum mismatch." }

Expand-Archive -Path $archive -DestinationPath $infracostDir -Force
$executables = @(Get-ChildItem $infracostDir -Recurse -File -Filter "infracost*.exe")
if ($executables.Count -ne 1) { throw "Expected one Infracost executable." }
$infracostExe = $executables[0].FullName

& $infracostExe --version
& $infracostExe auth login
```

After login succeeds, copy the key to your clipboard and paste it into the GitHub repository secret `INFRACOST_API_KEY`:

```powershell
# Do not paste the API key into chat, workflow YAML, or Git.
& $infracostExe configure get api_key | Set-Clipboard
```

This install uses the verified Windows amd64 release asset for your Windows AMD64 machine. If auth or download fails, resolve that step before proceeding.

Infracost contacts its external pricing service. Dashboard uploads are disabled in this workflow. Review organizational data-sharing requirements before using real confidential infrastructure plans. Raw plan JSON remains in runner temporary storage and is not uploaded as a GitHub artifact; normal plan text/artifacts can still contain sensitive values.

References:
https://github.com/infracost/infracost/releases/tag/v0.10.43
https://github.com/infracost/actions/tree/v3/setup

## 5. Update only the planning role trust policy

Your supplied trust policy uses immutable owner and repository IDs. The included policy preserves the existing main subject and adds this exact PR subject:

`repo:Ikteaja@56071290/aws-ai-infrastructure-platform@1361265436:pull_request`

It does not add a wildcard repository/branch trust. The apply role remains main-only.

Trust and cost-reporting permissions are now managed in Terraform bootstrap. Follow the saved-plan review procedure in [IAM-POLICY-MAP.md](IAM-POLICY-MAP.md); do not update them with manual IAM commands.

Important security boundary: AWS trusts the repo PR subject, not the workflow's author check. The owner-only/same-repo conditions are defense in depth in editable workflow code. Keep repository write access limited to trusted people. Terraform plans can execute provider/data-source code and read sensitive remote state. Do not grant the planning role infrastructure-write access. Keep only the necessary state-lock write permissions. Reassess this design if external collaborators are introduced. Do not switch to pull_request_target to run untrusted Terraform.

Reference: https://docs.github.com/en/actions/reference/security/oidc

## 6. AWS cost and network prerequisites

Cost Explorer must be enabled in AWS Billing and Cost Management. First-time data preparation can delay reporting. The policy grants `ce:GetCostAndUsage`; it cannot override permission boundaries or explicit denies. Cost Explorer API requests are billed. This workflow makes one logical grouped cost query per successful plan, subject to AWS pagination. Avoid frequent scheduled runs.

The actual-cost report is ACCOUNT-WIDE across all regions. It is not filtered by project tags. Values use UnblendedCost and may include billing adjustments; they are provisional, not a final invoice. An empty response is labelled as no recorded groups, not proof of zero future cost.

Infracost estimates the FULL PROPOSED DEV ENVIRONMENT, not merely newly added resources. It is not a baseline cost difference. Usage-dependent and unsupported resources may be incomplete. There is no automatic monetary cap in this workflow because no budget threshold has been agreed.

Network module deployment still requires suitable network read permissions for planning and write permissions for apply. These files do not add those permissions. Your VPC flow-log finding also remains to be resolved; scanners remain blocking. A failed plan or scan is an expected visible failure, not a reason to disable the gate.

References:
https://docs.aws.amazon.com/cli/latest/reference/ce/get-cost-and-usage.html
https://aws.amazon.com/aws-cost-management/aws-cost-explorer/pricing/

## 7. Commit and test

```powershell
# Check the branch and review only the intended files.
git branch --show-current
git diff -- .github/workflows/terraform-plan.yml
git status --short

git add .github/workflows/terraform-plan.yml `
    infrastructure/terraform/bootstrap/policies/plan/trust.json `
    infrastructure/terraform/bootstrap/policies/plan/healthops-dev-cost-reporting.json `
    docs/terraform-pr-costs.md

git diff --cached --check
git diff --cached --stat
git commit -m "Plan Terraform on pull requests and report infrastructure costs"
git push
```

Open/update the PR targeting main. Expected jobs:

- Format, validate, and scan
- Generate development plan (now runs on an authorized PR)
- Terraform review gate

Both cost-report steps run only after a successful plan and destruction guard. Cost-report failures fail the planning job and final gate. Unauthorized PRs have no AWS-connected planning and the final gate fails explicitly.

PR report artifact: `terraform-pr-review-RUN_ID-ATTEMPT`.
Main apply artifact: `terraform-dev-RUN_ID-ATTEMPT`.

After all checks and review, merge. Wait for the new main planning run, inspect its costs and plan, then manually approve the existing apply workflow with that new run ID and `apply-dev`. Do not supply a PR run ID to apply.

## 8. Validation performed on the supplied replacement

- Parsed workflow YAML and checked required jobs.
- Checked shell script syntax and embedded Python syntax.
- Exercised cost report formatting with sample AWS responses and final gate success/failure behavior.
- Preserved main artifact naming/metadata expected by the supplied apply workflow.

No GitHub workflow run, AWS role update, billing query or real Terraform plan was executed by the assistant. Runtime verification happens in your account after the prerequisites above.
