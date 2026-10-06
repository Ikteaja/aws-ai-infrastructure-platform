resource "aws_cloudwatch_log_group" "cluster" {
  # checkov:skip=CKV_AWS_158:CloudWatch Logs encrypts this group at rest by default; a customer-managed key is unnecessary for this synthetic-data dev cluster.
  # checkov:skip=CKV_AWS_338:Dev control-plane logs are intentionally retained for 30 days to limit lab cost; increase retention before production.
  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = var.cluster_log_retention_days
  tags              = var.tags
}

data "aws_subnet" "private" {
  for_each = toset(var.private_subnet_ids)

  id = each.value
}

resource "aws_eks_cluster" "this" {
  name                          = var.name
  role_arn                      = var.cluster_role_arn
  version                       = var.kubernetes_version
  bootstrap_self_managed_addons = false

  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  # checkov:skip=CKV_AWS_39:This lab requires public kubectl access, restricted to the explicitly confirmed administrator IPv4 /32.
  # checkov:skip=CKV_AWS_58:Kubernetes 1.28 and later use EKS default envelope encryption for all Kubernetes API data with an AWS-owned KMS key.
  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [var.control_plane_security_group_id]
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = [var.administrator_public_ipv4_cidr]
  }

  tags = var.tags

  depends_on = [aws_cloudwatch_log_group.cluster]

  lifecycle {
    precondition {
      condition = alltrue([
        for subnet in data.aws_subnet.private : subnet.vpc_id == var.vpc_id
      ])
      error_message = "Every EKS subnet must belong to the existing configured VPC."
    }
  }
}

data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

data "aws_eks_addon_version" "pod_identity_agent" {
  addon_name         = "eks-pod-identity-agent"
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-pod-identity-agent"
  addon_version               = data.aws_eks_addon_version.pod_identity_agent.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = var.tags
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  addon_version               = data.aws_eks_addon_version.vpc_cni.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = var.tags

  pod_identity_association {
    service_account = "aws-node"
    role_arn        = var.vpc_cni_role_arn
  }

  depends_on = [aws_eks_addon.pod_identity_agent]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  addon_version               = data.aws_eks_addon_version.kube_proxy.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = var.tags
}

resource "aws_launch_template" "cpu_workers" {
  name                   = "${var.name}-cpu"
  update_default_version = true

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.worker_security_group_id]
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.worker_disk_size_gib
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name = "${var.name}-cpu-worker"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name = "${var.name}-cpu-worker"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.name}-cpu"
  })
}

resource "aws_eks_node_group" "cpu" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-cpu"
  node_role_arn   = var.worker_role_arn
  subnet_ids      = var.private_subnet_ids
  version         = aws_eks_cluster.this.version
  ami_type        = "AL2023_x86_64_STANDARD"
  capacity_type   = "ON_DEMAND"
  instance_types  = [var.cpu_instance_type]

  scaling_config {
    min_size     = var.node_min_size
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.cpu_workers.id
    version = tostring(aws_launch_template.cpu_workers.latest_version)
  }

  tags = var.tags

  depends_on = [
    aws_eks_addon.pod_identity_agent,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
  ]
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  addon_version               = data.aws_eks_addon_version.coredns.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  tags                        = var.tags

  depends_on = [aws_eks_node_group.cpu]
}

module "eks_admin_access" {
  source = "../eks-admin-access"

  cluster_name               = aws_eks_cluster.this.name
  aws_account_id             = var.aws_account_id
  administrator_iam_role_arn = var.administrator_iam_role_arn
}
