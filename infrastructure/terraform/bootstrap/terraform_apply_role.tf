# Live configuration preserved during initial adoption.
resource "aws_iam_role" "terraform_apply" {
  provider             = aws.iam
  name                 = "healthops-dev-terraform-apply"
  path                 = "/"
  description          = "healthops-dev-terraform-apply-permissions"
  max_session_duration = 3600
  tags = {
    Name        = "healthops-dev-terraform-plan"
    Project     = "healthcare-operations-assistant"
    Environment = "dev"
    Component   = "terraform-plan"
    ManagedBy   = "Manual"
    Owner       = "Ikteaja"
  }
  assume_role_policy = jsonencode(jsondecode(file("${path.module}/policies/apply/trust.json")))
  lifecycle {
    prevent_destroy = true
  }
}
