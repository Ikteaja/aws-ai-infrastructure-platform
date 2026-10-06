resource "aws_iam_role" "eks_cluster" {
  provider = aws.iam

  name                 = "healthops-dev-eks-cluster"
  path                 = "/"
  description          = "EKS control-plane role for the ai-platform-dev cluster."
  assume_role_policy   = jsonencode(jsondecode(file("${path.module}/policies/eks/cluster-trust.json")))
  max_session_duration = 3600

  tags = {
    Name        = "healthops-dev-eks-cluster"
    Project     = "healthcare-operations-assistant"
    Environment = "dev"
    Component   = "eks-control-plane"
    ManagedBy   = "Terraform"
    Owner       = "Ikteaja"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  provider   = aws.iam
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_workers" {
  provider = aws.iam

  name                 = "healthops-dev-eks-workers"
  path                 = "/"
  description          = "EC2 worker-node role for the ai-platform-dev EKS cluster."
  assume_role_policy   = jsonencode(jsondecode(file("${path.module}/policies/eks/workers-trust.json")))
  max_session_duration = 3600

  tags = {
    Name        = "healthops-dev-eks-workers"
    Project     = "healthcare-operations-assistant"
    Environment = "dev"
    Component   = "eks-workers"
    ManagedBy   = "Terraform"
    Owner       = "Ikteaja"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "eks_workers" {
  provider   = aws.iam
  role       = aws_iam_role.eks_workers.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_workers_ecr_pull" {
  provider   = aws.iam
  role       = aws_iam_role.eks_workers.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

resource "aws_iam_role" "eks_vpc_cni" {
  provider = aws.iam

  name                 = "healthops-dev-eks-vpc-cni"
  path                 = "/"
  description          = "Pod Identity role for the ai-platform-dev VPC CNI add-on."
  assume_role_policy   = jsonencode(jsondecode(file("${path.module}/policies/eks/vpc-cni-pod-identity-trust.json")))
  max_session_duration = 3600

  tags = {
    Name        = "healthops-dev-eks-vpc-cni"
    Project     = "healthcare-operations-assistant"
    Environment = "dev"
    Component   = "eks-vpc-cni"
    ManagedBy   = "Terraform"
    Owner       = "Ikteaja"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "eks_vpc_cni" {
  provider   = aws.iam
  role       = aws_iam_role.eks_vpc_cni.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
