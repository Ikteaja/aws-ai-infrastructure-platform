resource "aws_iam_role" "eks_admin" {
  provider = aws.iam

  name                 = "healthops-dev-eks-admin"
  path                 = "/"
  description          = "Dedicated HealthOps dev EKS Kubernetes administrator role."
  max_session_duration = 3600
  assume_role_policy = jsonencode(jsondecode(file(
    "${path.module}/policies/eks-admin/trust.json"
  )))

  tags = {
    Name        = "healthops-dev-eks-admin"
    Project     = "healthcare-operations-assistant"
    Environment = "dev"
    Component   = "eks-administrator"
    ManagedBy   = "Terraform"
    Owner       = "Ikteaja"
  }

  lifecycle {
    prevent_destroy = true
  }
}
