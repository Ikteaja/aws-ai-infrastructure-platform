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