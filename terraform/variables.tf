variable "region" {
  description = "AWS region for the edge cluster."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment tag (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "omni-obs-aws"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.29"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to spread the cluster across."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24", "10.20.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ."
  type        = list(string)
  default     = ["10.20.101.0/24", "10.20.102.0/24", "10.20.103.0/24"]
}

variable "node_instance_types" {
  description = "EC2 instance types for managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  description = "Minimum size of the managed node group."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum size of the managed node group."
  type        = number
  default     = 6
}

variable "node_desired_size" {
  description = "Desired size of the managed node group."
  type        = number
  default     = 3
}
