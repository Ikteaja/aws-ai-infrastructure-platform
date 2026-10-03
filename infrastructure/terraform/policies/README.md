# Future policy proposals

This directory contains future ECR proposals, not automatically deployed policies.
Active deployment permissions live in `../bootstrap/policies/`. Duplicate earlier
policy and trust documents were removed after verifying they matched the active copies.

| Files | Status |
|---|---|
| `ecr-plan.json`, `ecr-apply.json` | Future ECR proposals; no matching live role policies found |

See [IAM-POLICY-MAP.md](../../../docs/IAM-POLICY-MAP.md). Edit bootstrap policy documents for deployment access and module policies for workloads. Avoid duplicate active sources.
