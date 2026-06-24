data "aws_iam_policy_document" "eks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "ai-platform-${var.environment}-eks-cluster"
  assume_role_policy = data.aws_iam_policy_document.eks_assume_role.json
  
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  ]
}

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_nodes" {
  name               = "ai-platform-${var.environment}-eks-nodes"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
  
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

resource "aws_iam_instance_profile" "gpu_node" {
  name = "ai-platform-${var.environment}-gpu-node"
  role = aws_iam_role.eks_nodes.name
}

# KServe IRSA role for S3 model access
data "aws_iam_policy_document" "kserve_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(var.oidc_provider_url, "https://", "")}"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(var.oidc_provider_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.namespace}:kserve-controller"]
    }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "kserve" {
  name               = "ai-platform-${var.environment}-kserve"
  assume_role_policy = data.aws_iam_policy_document.kserve_assume_role.json
}

resource "aws_iam_policy" "kserve_s3" {
  name = "ai-platform-${var.environment}-kserve-s3"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::ai-platform-models-${var.environment}/*",
          "arn:aws:s3:::ai-platform-models-${var.environment}"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "kserve_s3" {
  role       = aws_iam_role.kserve.name
  policy_arn = aws_iam_policy.kserve_s3.arn
}
