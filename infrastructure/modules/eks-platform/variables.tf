variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "kubernetes_version" {
  description = "Kubernetes minor version (e.g. 1.30)."
  type        = string
  default     = "1.30"
}

variable "vpc_cidr" {
  description = "CIDR block for the cluster VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group."
  type        = list(string)
  default     = ["t3.large"]
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 6
}

variable "node_desired_size" {
  type    = number
  default = 3
}

variable "argocd_chart_version" {
  description = "Helm chart version for Argo CD."
  type        = string
  default     = "7.6.12"
}

variable "argocd_admin_password_bcrypt" {
  description = "Bcrypt hash of the Argo CD admin password. Generate with: argocd account bcrypt --password ..."
  type        = string
  sensitive   = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
