# Live configuration preserved during initial adoption.
resource "aws_iam_role" "terraform_plan" {
  provider             = aws.iam
  name                 = "healthops-dev-terraform-plan-permissions"
  path                 = "/"
  description          = "Allows GitHub Actions to plan Terraform changes in dev."
  max_session_duration = 3600
  tags = {
    Name        = "healthops-dev-terraform-plan"
    Project     = "healthcare-operations-assistant"
    Environment = "dev"
    Component   = "terraform-plan"
    ManagedBy   = "manual"
    Owner       = "Ikteaja"
  }
  assume_role_policy = jsonencode(jsondecode(file("${path.module}/policies/plan/trust.json")))
  lifecycle {
    prevent_destroy = true
  }
}
