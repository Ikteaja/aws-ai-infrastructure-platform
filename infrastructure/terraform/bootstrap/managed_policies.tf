# Read-only network inventory for dev planning; bootstrap manages its attachment.
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

resource "aws_iam_policy" "network_egress_apply" {
  provider    = aws.iam
  name        = "healthops-dev-network-egress-apply"
  path        = "/"
  description = "Manage NAT, internet-gateway, S3-endpoint and EKS security-group resources for the dev VPC."

  tags = {
    Project     = "healthcare-operations-assistant"
    Environment = "dev"
    Owner       = "Ikteaja"
    ManagedBy   = "Terraform"
  }

  policy = jsonencode(jsondecode(file(
    "${path.module}/policies/managed/network-egress-apply.json"
  )))
}

resource "aws_iam_role_policy_attachment" "terraform_apply_network_egress" {
  provider = aws.iam

  role       = aws_iam_role.terraform_apply.name
  policy_arn = aws_iam_policy.network_egress_apply.arn
}

resource "aws_iam_policy" "eks_plan_read" {
  provider    = aws.iam
  name        = "healthops-dev-eks-plan-read"
  path        = "/"
  description = "Read the ai-platform-dev EKS cluster and its managed resources during Terraform planning."
  policy      = jsonencode(jsondecode(file("${path.module}/policies/managed/eks-plan-read.json")))

  tags = {
    Project     = "healthcare-operations-assistant"
    Environment = "dev"
    Owner       = "Ikteaja"
    ManagedBy   = "Terraform"
    Component   = "eks"
  }
}

resource "aws_iam_role_policy_attachment" "terraform_plan_eks_read" {
  provider = aws.iam

  role       = aws_iam_role.terraform_plan.name
  policy_arn = aws_iam_policy.eks_plan_read.arn
}

resource "aws_iam_policy" "eks_apply" {
  provider    = aws.iam
  name        = "healthops-dev-eks-apply"
  path        = "/"
  description = "Manage only the ai-platform-dev EKS cluster, CPU node group, add-ons and launch template."
  policy      = jsonencode(jsondecode(file("${path.module}/policies/managed/eks-apply.json")))

  tags = {
    Project     = "healthcare-operations-assistant"
    Environment = "dev"
    Owner       = "Ikteaja"
    ManagedBy   = "Terraform"
    Component   = "eks"
  }
}

resource "aws_iam_role_policy_attachment" "terraform_apply_eks" {
  provider = aws.iam

  role       = aws_iam_role.terraform_apply.name
  policy_arn = aws_iam_policy.eks_apply.arn
}