output "eks_cluster_role_arn" { value = aws_iam_role.eks_cluster.arn }
output "eks_node_role_arn" { value = aws_iam_role.eks_nodes.arn }
output "gpu_node_instance_profile" { value = aws_iam_instance_profile.gpu_node.name }
output "kserve_role_arn" { value = aws_iam_role.kserve.arn }
