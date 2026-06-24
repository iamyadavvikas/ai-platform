module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"

  cluster_endpoint_public_access = true

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # EKS managed node group for CPU workloads
  eks_managed_node_groups = {
    cpu = {
      desired_size = 1
      min_size     = 1
      max_size     = 6

      instance_types = [var.cpu_instance_type]
      capacity_type  = "ON_DEMAND"

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 50
            volume_type = "gp3"
          }
        }
      }
    }
  }

  # Self-managed node group for GPU workloads
  self_managed_node_groups = {
    gpu = {
      name = "gpu-nodes"

      launch_template_name        = "ai-platform-${var.environment}-gpu"
      launch_template_description = "GPU nodes for LLM inference"

      instance_type = var.gpu_instance_type

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 200
            volume_type = "gp3"
          }
        }
      }

      min_size     = var.gpu_min_size
      max_size     = var.gpu_max_size
      desired_size = var.gpu_desired_size

      bootstrap_extra_args = "--kubelet-extra-args '--node-labels=node.kubernetes.io/instance-type=gpu --register-with-taints=nvidia.com/gpu=true:NoSchedule'"

      iam_instance_profile = var.gpu_node_instance_profile
    }
  }

  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
    aws-ebs-csi-driver = { most_recent = true }
  }

  tags = {
    Environment = var.environment
    Project     = "ai-platform"
  }
}

resource "aws_eks_addon" "aws-efs-csi" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-efs-csi-driver"
}
