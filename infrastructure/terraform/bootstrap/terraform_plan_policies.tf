resource "aws_iam_role_policy" "terraform_plan_cost_reporting" {
  provider = aws.iam
  name     = "healthops-dev-cost-reporting"
  role     = aws_iam_role.terraform_plan.name
  policy   = jsonencode(jsondecode(file("${path.module}/policies/plan/healthops-dev-cost-reporting.json")))
}

resource "aws_iam_role_policy" "terraform_plan_kms" {
  provider = aws.iam
  name     = "healthops-dev-kms-plan"
  role     = aws_iam_role.terraform_plan.name
  policy   = jsonencode(jsondecode(file("${path.module}/policies/plan/healthops-dev-kms-plan.json")))
}

resource "aws_iam_role_policy" "terraform_plan_permissions" {
  provider = aws.iam
  name     = "healthops-dev-terraform-plan-permissions"
  role     = aws_iam_role.terraform_plan.name
  policy   = jsonencode(jsondecode(file("${path.module}/policies/plan/healthops-dev-terraform-plan-permissions.json")))
}
