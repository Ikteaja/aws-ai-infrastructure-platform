# Return the VPC ID so the future EKS module can use this network.
output "vpc_id" {
  description = "ID of the VPC created by the network module."
  value       = aws_vpc.this.id
}

# Return subnet IDs while preserving their keys: a and b.
# Example consumer: module.network.private_subnet_ids.
output "private_subnet_ids" {
  description = "Private subnet IDs indexed by subnet key."

  value = {
    for key, subnet in aws_subnet.private :
    key => subnet.id
  }
}

# Return route-table IDs for later outbound-routing configuration.
output "private_route_table_ids" {
  description = "Private route-table IDs indexed by subnet key."

  value = {
    for key, route_table in aws_route_table.private :
    key => route_table.id
  }
}

output "public_subnet_ids" {
  description = "Public subnet IDs indexed by subnet key."

  value = {
    for key, subnet in aws_subnet.public :
    key => subnet.id
  }
}

output "nat_gateway_id" {
  description = "ID of the single lab NAT gateway; shared by private subnet routes."
  value       = aws_nat_gateway.lab.id
}

output "s3_gateway_endpoint_id" {
  description = "ID of the S3 gateway endpoint associated with private route tables."
  value       = aws_vpc_endpoint.s3.id
}

output "eks_control_plane_security_group_id" {
  description = "Additional control-plane security group prepared for the future EKS cluster."
  value       = aws_security_group.eks_control_plane.id
}

output "eks_worker_security_group_id" {
  description = "Worker security group prepared for the future EKS managed node group."
  value       = aws_security_group.eks_workers.id
}