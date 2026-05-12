###############################################################################
# Reference Terraform for deploying one edge cluster to AWS.
#
# This file is NOT applied by `make demo` — the demo runs entirely on local
# kind clusters. This is reference IaC so a recruiter or operator can see what
# the production-shaped equivalent of the kind setup looks like.
#
# To use:
#   terraform init
#   terraform plan -var="region=us-east-1" -var="cluster_name=omni-obs-aws"
#   terraform apply
#
# Prerequisites:
#   - AWS credentials (env, ~/.aws/credentials, or assumed role)
#   - Terraform >= 1.6
#
# This deploys an EKS cluster sized for a single edge of the Omni-Obs platform.
# The Kustomize overlay at kubernetes/overlays/aws/ would then be applied via
# Argo CD or `kubectl apply -k`.
###############################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }

  # Uncomment and configure for real use.
  # backend "s3" {
  #   bucket         = "omni-obs-tfstate"
  #   key            = "edge/aws/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "omni-obs-tflock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = "omni-obs-platform"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}

###############################################################################
# Networking — minimal VPC for the edge cluster.
###############################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.5"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway   = true
  single_nat_gateway   = true # demo budget; production = one per AZ
  enable_dns_hostnames = true

  # Tags required for EKS LB controller to discover subnets.
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

###############################################################################
# EKS cluster.
###############################################################################

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Required addons for the platform to function correctly.
  cluster_addons = {
    coredns            = { most_recent = true }
    kube-proxy         = { most_recent = true }
    vpc-cni            = { most_recent = true }
    aws-ebs-csi-driver = { most_recent = true }
  }

  eks_managed_node_groups = {
    edge = {
      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      labels = {
        role = "edge"
      }
    }
  }
}

###############################################################################
# Outputs consumed by the kustomize apply step.
###############################################################################

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig for this cluster."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}
