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