# These additional security groups are prepared for the future EKS cluster and
# managed node group. The cluster's AWS-managed security group remains in use.
resource "aws_security_group" "eks_control_plane" {
  # checkov:skip=CKV2_AWS_5:EKS is not created in this milestone; attach this prepared group when the future cluster is provisioned.
  name        = "${var.name}-eks-control-plane"
  description = "Additional EKS control-plane security group for ${var.name}."
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-eks-control-plane"
  })
}

resource "aws_security_group" "eks_workers" {
  # checkov:skip=CKV2_AWS_5:EKS workers are not created in this milestone; attach this prepared group to the future node group.
  name        = "${var.name}-eks-workers"
  description = "EKS worker security group for ${var.name}; no SSH ingress."
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-eks-workers"
  })
}

resource "aws_vpc_security_group_ingress_rule" "eks_api_from_workers" {
  security_group_id            = aws_security_group.eks_control_plane.id
  referenced_security_group_id = aws_security_group.eks_workers.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "Worker nodes connect to the Kubernetes API."
}

resource "aws_vpc_security_group_egress_rule" "eks_control_plane_to_workers" {
  security_group_id            = aws_security_group.eks_control_plane.id
  referenced_security_group_id = aws_security_group.eks_workers.id
  ip_protocol                  = "tcp"
  from_port                    = 10250
  to_port                      = 10250
  description                  = "Control plane reaches the worker kubelet."
}

resource "aws_vpc_security_group_egress_rule" "eks_control_plane_https_to_workers" {
  security_group_id            = aws_security_group.eks_control_plane.id
  referenced_security_group_id = aws_security_group.eks_workers.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "Control plane reaches HTTPS webhooks on workers."
}

resource "aws_vpc_security_group_ingress_rule" "eks_workers_from_control_plane" {
  security_group_id            = aws_security_group.eks_workers.id
  referenced_security_group_id = aws_security_group.eks_control_plane.id
  ip_protocol                  = "tcp"
  from_port                    = 10250
  to_port                      = 10250
  description                  = "Control plane reaches the worker kubelet."
}

resource "aws_vpc_security_group_ingress_rule" "eks_workers_https_from_control_plane" {
  security_group_id            = aws_security_group.eks_workers.id
  referenced_security_group_id = aws_security_group.eks_control_plane.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "Control plane reaches HTTPS webhooks on workers."
}

resource "aws_vpc_security_group_ingress_rule" "eks_workers_from_workers" {
  security_group_id            = aws_security_group.eks_workers.id
  referenced_security_group_id = aws_security_group.eks_workers.id
  ip_protocol                  = "-1"
  description                  = "Allow required node-to-node and pod traffic."
}

resource "aws_vpc_security_group_egress_rule" "eks_workers_to_control_plane" {
  security_group_id            = aws_security_group.eks_workers.id
  referenced_security_group_id = aws_security_group.eks_control_plane.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "Workers connect to the Kubernetes API."
}

# Required lab exception: private workers need HTTPS to ECR, GitHub, and external
# registries whose public addresses change. Workers have no public IP; the subnet
# route sends this stateful outbound traffic through the NAT Gateway. There is no
# inbound internet rule. Replace with an egress firewall/proxy before production.
#trivy:ignore:AWS-0104
resource "aws_vpc_security_group_egress_rule" "eks_workers_https" {
  security_group_id = aws_security_group.eks_workers.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "Workers reach ECR, AWS APIs, GitHub, and external registries through NAT."
}

resource "aws_vpc_security_group_egress_rule" "eks_workers_dns_udp" {
  security_group_id = aws_security_group.eks_workers.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  description       = "Workers resolve VPC and public service names."
}

resource "aws_vpc_security_group_egress_rule" "eks_workers_dns_tcp" {
  security_group_id = aws_security_group.eks_workers.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  description       = "Workers resolve large DNS responses over TCP."
}

resource "aws_vpc_security_group_egress_rule" "eks_workers_to_workers" {
  security_group_id            = aws_security_group.eks_workers.id
  referenced_security_group_id = aws_security_group.eks_workers.id
  ip_protocol                  = "-1"
  description                  = "Allow required node-to-node and pod traffic."
}
