# Terraform Remote State

## Goal

Store Terraform infrastructure records securely in S3 so local
planning and pipeline deployments use the same state.

## Storage

- Bucket: `healthops-tfstate-429496640190-eu-central-1`
- Region: `eu-central-1`
- Hospital documents are stored in a separate bucket.

| Configuration | State key |
|---|---|
| Bootstrap foundation | `bootstrap/terraform.tfstate` |
| Development | `dev/terraform.tfstate` |
| Test | `test/terraform.tfstate` |
| Production demo | `prd/terraform.tfstate` |

## Security Controls

- All public access is blocked.
- Legacy access-control lists are disabled.
- New objects use default S3-managed encryption.
- Bucket policy rejects requests without HTTPS.
- Versioning retains previous state versions.
- Native S3 locking prevents simultaneous state writes.
- Terraform deletion protection guards the state bucket.
- Credentials, state files and saved plans stay outside Git.

Access still depends on IAM permissions. Each pipeline role should
have access only to its environment's state and required resources.

## Initial Setup

1. Initialize the bootstrap configuration using local state.
2. Review the plan.
3. Apply once using an authorized administrator identity.
4. Add the S3 backend configuration.
5. Run `terraform init -migrate-state`.
6. Verify the migrated state and confirm a no-change plan.

If the bucket already exists, import it and its settings instead
of attempting to recreate it.

## Deployment Workflow

1. Developer checks the plan locally.
2. Reviewed configuration is committed.
3. Pipeline generates a deployment plan.
4. The owner approves the plan.
5. Pipeline applies the saved plan.
6. Terraform updates remote state and releases its lock.

The bucket setup alone does not configure pipeline approval.

## Recovery and Cleanup

- State can contain sensitive values; restrict access.
- Retain previous versions for recovery.
- Before recovery, stop all Terraform operations and investigate.
- Never delete a lock until its owning operation is confirmed stopped.
- Do not delete the state bucket during normal environment cleanup.
- `prevent_destroy` is a Terraform guard, not an AWS access restriction.