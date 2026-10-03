# Existing unattached policy: adoption does not grant additional permissions.
resource "aws_iam_policy" "network_plan_read" {
  provider    = aws.iam
  name        = "healthops-dev-network-plan-read"
  path        = "/"
  description = "Read existing dev networking during Terraform planning"
  tags = {
    Project     = "healthcare-operations-assistant"
    Environment = "dev"
    Owner       = "Ikteaja"
    ManagedBy   = "ManualBootstrap"
  }
  policy = jsonencode(jsondecode(file("${path.module}/policies/managed/network-plan-read.json")))
}

resource "aws_iam_role_policy_attachment" "terraform_plan_network_read" {
  provider = aws.iam

  role       = aws_iam_role.terraform_plan.name
  policy_arn = aws_iam_policy.network_plan_read.arn
}