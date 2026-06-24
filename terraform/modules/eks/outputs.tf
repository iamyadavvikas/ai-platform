output "cluster_id" { value = module.eks.cluster_id }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "cluster_ca_certificate" { value = module.eks.cluster_certificate_authority_data }
output "oidc_provider_arn" { value = module.eks.oidc_provider_arn }
output "oidc_provider_url" { value = module.eks.cluster_oidc_issuer_url }
output "node_security_group_id" { value = module.eks.node_security_group_id }
