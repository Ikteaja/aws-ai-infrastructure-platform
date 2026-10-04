# ------------------------------------------------------------
# VPC: the private address space containing our network resources.
# ------------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  # Enable AWS DNS resolution inside the VPC.
  enable_dns_support = true

  # Enable DNS hostname support.
  # This is also useful for future private service endpoints.
  enable_dns_hostnames = true

  # Add a resource-specific Name to the common environment tags.
  tags = merge(var.tags, {
    Name = "${var.name}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}


# ------------------------------------------------------------
# SUBNETS: public egress/load-balancer subnets and private workers.
# ------------------------------------------------------------
resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name                                = "${var.name}-public-${each.key}"
    "kubernetes.io/role/elb"            = "1"
    "kubernetes.io/cluster/${var.name}" = "shared"
  })
}

resource "aws_subnet" "private" {
  # Create one subnet for each map entry, such as 'a' and 'b'.
  for_each = var.private_subnets

  # Place every subnet inside the VPC created above.
  vpc_id = aws_vpc.this.id

  # Read this subnet's settings from its map entry.
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  # Do not automatically assign public IPv4 addresses to instances.
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name                                = "${var.name}-private-${each.key}"
    "kubernetes.io/cluster/${var.name}" = "shared"

    # Identify subnets suitable for future internal load balancers.
    # This tag does not create a load balancer or security rule.
    "kubernetes.io/role/internal-elb" = "1"
  })
}


# ------------------------------------------------------------
# ROUTE TABLES: define where traffic from each subnet can travel.
# ------------------------------------------------------------
resource "aws_route_table" "private" {
  # Create one route table per subnet using the same map keys.
  for_each = var.private_subnets

  # Route tables and their associated subnets belong to the same VPC.
  vpc_id = aws_vpc.this.id

  # AWS automatically adds a local route for the VPC address range.
  # A separate aws_route below sends external traffic through the NAT gateway.

  tags = merge(var.tags, {
    Name = "${var.name}-private-${each.key}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-public"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route" "private_nat" {
  for_each = var.private_subnets

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.lab.id
}

resource "aws_route_table_association" "public" {
  for_each = var.public_subnets

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-nat-eip"
  })
}

resource "aws_nat_gateway" "lab" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[sort(keys(var.public_subnets))[0]].id

  depends_on = [aws_route.public_internet]

  tags = merge(var.tags, {
    Name = "${var.name}-nat"
  })
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for route_table in aws_route_table.private : route_table.id]

  tags = merge(var.tags, {
    Name = "${var.name}-s3"
  })
}

# ------------------------------------------------------------
# ASSOCIATIONS: connect each subnet to its matching route table.
# ------------------------------------------------------------
resource "aws_route_table_association" "private" {
  for_each = var.private_subnets

  # Key 'a' connects subnet a to route table a.
  # Key 'b' connects subnet b to route table b.
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}


# ------------------------------------------------------------
# DEFAULT SECURITY GROUP: remove AWS's initial default rules.
# ------------------------------------------------------------
resource "aws_default_security_group" "restricted" {
  # Manage only the default security group of this new VPC.
  vpc_id = aws_vpc.this.id

  # Configure no inbound or outbound allow rules.
  # Future EKS workloads will use dedicated security groups.
  ingress = []
  egress  = []

  tags = merge(var.tags, {
    Name = "${var.name}-default-restricted"
  })
}