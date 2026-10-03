resource "aws_iam_role_policy" "kms_apply" {
  provider = aws.iam
  name     = "healthops-dev-kms-apply"
  role     = aws_iam_role.terraform_apply.name
  policy   = jsonencode(jsondecode(file("${path.module}/policies/apply/healthops-dev-kms-apply.json")))
}

resource "aws_iam_role_policy" "network_apply" {
  provider = aws.iam
  name     = "healthops-dev-network-apply"
  role     = aws_iam_role.terraform_apply.name
  policy   = jsonencode(jsondecode(file("${path.module}/policies/apply/healthops-dev-network-apply.json")))
}

resource "aws_iam_role_policy" "terraform_apply" {
  provider = aws.iam
  name     = "healthops-dev-terraform-apply"
  role     = aws_iam_role.terraform_apply.name
  policy   = jsonencode(jsondecode(file("${path.module}/policies/apply/healthops-dev-terraform-apply.json")))
}

resource "aws_iam_role_policy" "terraform_apply_permissions" {
  provider = aws.iam
  name     = "healthops-dev-terraform-apply-permissions"
  role     = aws_iam_role.terraform_apply.name
  policy   = jsonencode(jsondecode(file("${path.module}/policies/apply/healthops-dev-terraform-apply-permissions.json")))
}
