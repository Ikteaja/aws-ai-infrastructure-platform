# Prefix used to name the VPC, subnets and route tables.
# Example supplied by dev: healthops-dev.
variable "name" {
  description = "Name prefix for network resources."
  type        = string
}

# Complete IPv4 address range assigned to the VPC.
# Each subnet must fit inside this range.
variable "vpc_cidr" {
  description = "IPv4 address range for the VPC."
  type        = string

  # Reject an invalid IPv4 CIDR before attempting deployment.
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "Provide a valid IPv4 CIDR, such as 10.40.0.0/16."
  }
}

# The root module supplies a map of subnet configurations.
# Keys such as 'a' and 'b' identify matching subnets and route tables.
variable "private_subnets" {
  description = "Private subnet address ranges and Availability Zones."

  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))

  # EKS needs subnets in at least two different Availability Zones.
  validation {
    condition = length(distinct([
      for subnet in values(var.private_subnets) :
      subnet.availability_zone
    ])) >= 2

    error_message = "Provide subnets in at least two different Availability Zones."
  }

  # Confirm that every subnet uses a valid IPv4 CIDR.
  validation {
    condition = alltrue([
      for subnet in values(var.private_subnets) :
      can(cidrnetmask(subnet.cidr_block))
    ])

    error_message = "Every subnet must have a valid IPv4 CIDR."
  }
}

# Public subnets host internet-facing infrastructure such as the single lab NAT
# gateway. Worker nodes remain in private_subnets and receive no public IPs.
variable "public_subnets" {
  description = "Public IPv4 subnet ranges and Availability Zones."

  type = map(object({
    cidr_block        = string
    availability_zone = string
  }))

  validation {
    condition = length(distinct([
      for subnet in values(var.public_subnets) :
      subnet.availability_zone
    ])) >= 2

    error_message = "Provide public subnets in at least two different Availability Zones."
  }

  validation {
    condition = alltrue([
      for subnet in values(var.public_subnets) :
      can(cidrnetmask(subnet.cidr_block))
    ])

    error_message = "Every public subnet must have a valid IPv4 CIDR."
  }
}

# Common labels identify ownership, environment and purpose.
variable "tags" {
  description = "Common tags applied to network resources."
  type        = map(string)
}