# Retain as the adoption record. Existing state entries are not imported twice.
import {
  to = aws_iam_role.terraform_plan
  id = "healthops-dev-terraform-plan-permissions"
}

import {
  to = aws_iam_role_policy.terraform_plan_cost_reporting
  id = "healthops-dev-terraform-plan-permissions:healthops-dev-cost-reporting"
}

import {
  to = aws_iam_role_policy.terraform_plan_kms
  id = "healthops-dev-terraform-plan-permissions:healthops-dev-kms-plan"
}

import {
  to = aws_iam_role_policy.terraform_plan_permissions
  id = "healthops-dev-terraform-plan-permissions:healthops-dev-terraform-plan-permissions"
}

import {
  to = aws_iam_role.terraform_apply
  id = "healthops-dev-terraform-apply"
}

import {
  to = aws_iam_role_policy.kms_apply
  id = "healthops-dev-terraform-apply:healthops-dev-kms-apply"
}

import {
  to = aws_iam_role_policy.network_apply
  id = "healthops-dev-terraform-apply:healthops-dev-network-apply"
}

import {
  to = aws_iam_role_policy.terraform_apply
  id = "healthops-dev-terraform-apply:healthops-dev-terraform-apply"
}

import {
  to = aws_iam_role_policy.terraform_apply_permissions
  id = "healthops-dev-terraform-apply:healthops-dev-terraform-apply-permissions"
}

import {
  to = aws_iam_policy.network_plan_read
  id = "arn:aws:iam::429496640190:policy/healthops-dev-network-plan-read"
}

import {
  to = aws_iam_openid_connect_provider.github
  id = "arn:aws:iam::429496640190:oidc-provider/token.actions.githubusercontent.com"
}
