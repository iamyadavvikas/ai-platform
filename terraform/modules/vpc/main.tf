terraform {
  required_version = ">= 1.0"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "ai-platform-${var.environment}"
  cidr = var.vpc_cidr

  azs             = var.azs
  private_subnets = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 8, i + 48)]
  database_subnets = [for i, az in var.azs : cidrsubnet(var.vpc_cidr, 4, i + 16)]

  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
  enable_vpn_gateway     = false
  enable_dns_hostnames   = true
  enable_dns_support     = true

  # VPC endpoints for S3 and ECR (keep traffic within AWS network)
  enable_s3_endpoint     = true
  enable_ecr_api_endpoint  = true
  enable_ecr_dkr_endpoint  = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = {
    Environment = var.environment
    Project     = "ai-platform"
    ManagedBy   = "terraform"
  }
}
