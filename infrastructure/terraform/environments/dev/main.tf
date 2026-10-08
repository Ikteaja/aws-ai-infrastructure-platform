# Call our reusable document-storage module.
module "document_storage" {
  source = "../../modules/document-storage"

  # Pass the lab's bucket name into the module.
  bucket_name = var.document_bucket_name

  # These tags must match the conditions in our AWS permissions.
  tags = {
    Project     = "healthcare-operations-assistant"
    Environment = "dev"
    ManagedBy   = "Terraform"
    DataType    = "synthetic"
  }
}
#####################network modules############################
# Create the development network using our reusable module.
module "network" {
  # Resolve the module directory relative to environments/dev.
  source = "../../modules/network"

  # Prefix used in resource Name tags.
  name = "healthops-dev"

  # Reserve the VPC's private address space.
  vpc_cidr = "10.40.0.0/16"

  # Supply the subnet configuration to the child module.
  # The keys also map subnets to their route tables.
  private_subnets = {
    a = {
      cidr_block        = "10.40.16.0/20"
      availability_zone = "eu-central-1a"
    }

    b = {
      cidr_block        = "10.40.32.0/20"
      availability_zone = "eu-central-1b"
    }
  }

  # Only the NAT gateway uses a public subnet; worker nodes remain private.
  public_subnets = {
    a = {
      cidr_block        = "10.40.0.0/24"
      availability_zone = "eu-central-1a"
    }

    b = {
      cidr_block        = "10.40.1.0/24"
      availability_zone = "eu-central-1b"
    }
  }

  # Identify the environment, owner and resource purpose.
  tags = {
    Project     = "healthcare-operations-assistant"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Component   = "network"
    Owner       = "Ikteaja"
  }
}

#Module: ECR
module "ecr" {
  source = "../../modules/ecr"

  name_prefix = "healthops-dev"

  repositories = [
    "api",
    "mock-model",
  ]

  tags = {
    Project     = "healthcare-operations-assistant"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Component   = "container-registry"
  }
}

data "aws_iam_role" "eks_cluster" {
  name = "healthops-dev-eks-cluster"
}

data "aws_iam_role" "eks_workers" {
  name = "healthops-dev-eks-workers"
}

data "aws_iam_role" "eks_vpc_cni" {
  name = "healthops-dev-eks-vpc-cni"
}

module "eks" {
  source = "../../modules/eks"

  name                            = "ai-platform-dev"
  aws_account_id                  = var.aws_account_id
  kubernetes_version              = var.eks_kubernetes_version
  vpc_id                          = module.network.vpc_id
  private_subnet_ids              = values(module.network.private_subnet_ids)
  control_plane_security_group_id = module.network.eks_control_plane_security_group_id
  worker_security_group_id        = module.network.eks_worker_security_group_id
  cluster_role_arn                = data.aws_iam_role.eks_cluster.arn
  worker_role_arn                 = data.aws_iam_role.eks_workers.arn
  vpc_cni_role_arn                = data.aws_iam_role.eks_vpc_cni.arn
  administrator_iam_role_arn      = var.eks_administrator.iam_role_arn
  administrator_public_ipv4_cidr  = var.eks_administrator.public_ipv4_cidr
  cpu_instance_type               = var.eks_cpu_instance_type
  node_min_size                   = var.eks_node_min_size
  node_desired_size               = var.eks_node_desired_size
  node_max_size                   = var.eks_node_max_size
  worker_disk_size_gib            = 30
  cluster_log_retention_days      = 30

  tags = {
    Project     = "healthcare-operations-assistant"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Component   = "eks"
    Owner       = "Ikteaja"
  }
}