terraform {
  backend "s3" {
    bucket         = "ai-platform-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "ai-platform-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "../../modules/vpc"

  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  azs                  = slice(data.aws_availability_zones.available.names, 0, 3)
  single_nat_gateway   = true
  enable_nat_gateway   = true
  cluster_name         = var.cluster_name
}

module "iam" {
  source = "../../modules/iam"

  environment      = var.environment
  cluster_name     = var.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  namespace        = "ai-platform"
}

module "eks" {
  source = "../../modules/eks"

  environment           = var.environment
  cluster_name          = var.cluster_name
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids
  cpu_instance_type     = var.cpu_instance_type
  gpu_instance_type     = var.gpu_instance_type
  gpu_min_size          = var.gpu_min_size
  gpu_max_size          = var.gpu_max_size
  gpu_desired_size      = 0
  gpu_node_instance_profile = module.iam.gpu_node_instance_profile
}
