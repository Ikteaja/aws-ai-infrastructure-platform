variable "name" {
  description = "Name of the EKS cluster and initial CPU managed node group."
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID that owns the cluster."
  type        = string
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version. Add-on versions are resolved as compatible with this version."
  type        = string
}

variable "private_subnet_ids" {
  description = "Existing private subnet IDs across the selected Availability Zones."
  type        = list(string)
}

variable "vpc_id" {
  description = "Existing VPC ID to validate the selected private subnets against."
  type        = string
}

variable "control_plane_security_group_id" {
  description = "Prepared additional EKS control-plane security group."
  type        = string
}

variable "worker_security_group_id" {
  description = "Prepared worker security group, attached through the managed node group's launch template."
  type        = string
}

variable "cluster_role_arn" {
  description = "Bootstrap-managed IAM role assumed by the EKS control plane."
  type        = string
}

variable "worker_role_arn" {
  description = "Bootstrap-managed IAM role assumed by EC2 worker nodes."
  type        = string
}

variable "vpc_cni_role_arn" {
  description = "Dedicated Pod Identity role for the VPC CNI add-on."
  type        = string
}

variable "administrator_iam_role_arn" {
  description = "Dedicated IAM role granted cluster-scoped EKS administrator access."
  type        = string
}

variable "administrator_public_ipv4_cidr" {
  description = "Currently verified administrator public IPv4 /32 for the public Kubernetes API endpoint."
  type        = string

  validation {
    condition = can(cidrnetmask(var.administrator_public_ipv4_cidr)) && try(
      split("/", var.administrator_public_ipv4_cidr)[1] == "32",
      false
    )
    error_message = "The public Kubernetes endpoint must be restricted to an explicit IPv4 /32."
  }
}

variable "cpu_instance_type" {
  description = "x86_64 EC2 instance type for the initial On-Demand CPU node group."
  type        = string
}

variable "node_min_size" {
  description = "Minimum number of CPU worker nodes."
  type        = number
}

variable "node_desired_size" {
  description = "Initial desired number of CPU worker nodes."
  type        = number
}

variable "node_max_size" {
  description = "Maximum number of CPU worker nodes; this does not enable automatic scaling by itself."
  type        = number
}

variable "worker_disk_size_gib" {
  description = "Encrypted gp3 root volume size for each CPU worker."
  type        = number
}

variable "cluster_log_retention_days" {
  description = "CloudWatch retention period for EKS control-plane logs."
  type        = number
}

variable "tags" {
  description = "Common tags applied to EKS resources."
  type        = map(string)
}
