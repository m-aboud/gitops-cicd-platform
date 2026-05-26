terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws        = { source = "hashicorp/aws", version = ">= 5.50" }
    helm       = { source = "hashicorp/helm", version = ">= 2.15" }
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.30" }
  }
}

locals {
  common_tags = merge(
    {
      Cluster   = var.cluster_name
      ManagedBy = "terraform"
      Module    = "eks-platform"
    },
    var.tags,
  )
}

# ------------------------------------------------------------------
# VPC
# ------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
  public_subnets  = ["10.20.101.0/24", "10.20.102.0/24", "10.20.103.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true   # cost-optimised; for prod use one per AZ
  enable_dns_hostnames = true

  # EKS load-balancer discovery tags
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = local.common_tags
}

# ------------------------------------------------------------------
# EKS cluster + managed node group
# ------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_addons = {
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { most_recent = true }
    aws-ebs-csi-driver     = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
  }

  eks_managed_node_groups = {
    main = {
      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      labels = {
        workload = "platform"
      }
    }
  }

  tags = local.common_tags
}

# ------------------------------------------------------------------
# Kubernetes & Helm providers — depend on cluster being live
# ------------------------------------------------------------------
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

# ------------------------------------------------------------------
# Bootstrap: namespaces
# ------------------------------------------------------------------
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
    labels = {
      "pod-security.kubernetes.io/enforce" = "baseline"
    }
  }
  depends_on = [module.eks]
}

# ------------------------------------------------------------------
# Bootstrap: Argo CD via Helm
# ------------------------------------------------------------------
resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  values = [
    yamlencode({
      configs = {
        secret = {
          argocdServerAdminPassword = var.argocd_admin_password_bcrypt
        }
        params = {
          "server.insecure" = true # behind cluster TLS / ingress
        }
      }
      server = {
        service = { type = "ClusterIP" }
      }
      controller = {
        metrics = { enabled = true }
      }
      notifications = {
        enabled = true
      }
    })
  ]
}

# ------------------------------------------------------------------
# Bootstrap: Argo Rollouts
# ------------------------------------------------------------------
resource "helm_release" "argo_rollouts" {
  name             = "argo-rollouts"
  namespace        = "argo-rollouts"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  version          = "2.37.7"

  depends_on = [module.eks]
}

# ------------------------------------------------------------------
# Bootstrap: Argo Events + Argo Workflows
# Argo Events ships event sources/sensors; Argo Workflows runs the
# triggered pipelines. Both required for event-driven CD.
# ------------------------------------------------------------------
resource "helm_release" "argo_events" {
  name             = "argo-events"
  namespace        = "argo-events"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-events"
  version          = "2.4.13"

  depends_on = [module.eks]
}

resource "helm_release" "argo_workflows" {
  name             = "argo-workflows"
  namespace        = "argo-events"   # co-locate with events for simpler RBAC
  create_namespace = false
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-workflows"
  version          = "0.42.3"

  set {
    name  = "workflow.serviceAccount.create"
    value = "false"        # we manage the SA in platform/argo-events/rbac.yaml
  }

  depends_on = [helm_release.argo_events]
}

# ------------------------------------------------------------------
# Bootstrap: Kyverno
# ------------------------------------------------------------------
resource "helm_release" "kyverno" {
  name             = "kyverno"
  namespace        = "kyverno"
  create_namespace = true
  repository       = "https://kyverno.github.io/kyverno/"
  chart            = "kyverno"
  version          = "3.3.3"

  depends_on = [module.eks]
}

# ------------------------------------------------------------------
# Bootstrap: External Secrets Operator
# ------------------------------------------------------------------
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.10.5"

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [module.eks]
}
