# Terraform policy ownership

Active ECR deployment permissions are maintained under
`../bootstrap/policies/plan/`, `../bootstrap/policies/apply/` and
`../bootstrap/policies/publisher/`. The bootstrap root attaches the plan and apply
permissions to their Terraform roles and creates a separate OIDC publisher role.
Do not create or attach duplicate managed policies manually.

See [IAM-POLICY-MAP.md](../../../docs/IAM-POLICY-MAP.md) for the policy source of
truth and controlled bootstrap procedure.
