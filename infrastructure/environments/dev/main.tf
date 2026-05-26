terraform {
  required_version = ">= 1.5.0"

  # Recommended for shared work: remote backend.
  # backend "s3" {
  #   bucket         = "your-tf-state-bucket"
  #   key            = "gitops-platform/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "tf-state-lock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = "gitops-cicd-platform"
      Environment = "dev"
      ManagedBy   = "terraform"
      Owner       = "mohammedabood"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "argocd_admin_password_bcrypt" {
  description = "Bcrypt hash of the Argo CD admin password."
  type        = string
  sensitive   = true
}

module "platform" {
  source = "../../modules/eks-platform"

  cluster_name                 = "gitops-platform-dev"
  region                       = var.region
  kubernetes_version           = "1.30"
  vpc_cidr                     = "10.20.0.0/16"
  node_instance_types          = ["t3.large"]
  node_desired_size            = 3
  argocd_admin_password_bcrypt = var.argocd_admin_password_bcrypt

  tags = {
    Environment = "dev"
  }
}

output "kubeconfig_command" {
  value = module.platform.kubeconfig_command
}

output "cluster_name" {
  value = module.platform.cluster_name
}
