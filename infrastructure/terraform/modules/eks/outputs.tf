output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_security_group_id" {
  description = "AWS-managed EKS cluster security group ID."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cpu_node_group_name" {
  description = "Initial CPU managed node group name."
  value       = aws_eks_node_group.cpu.node_group_name
}
