variable "environment" { type = string }
variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }
variable "enable_nat_gateway" { type = bool, default = true }
variable "single_nat_gateway" { type = bool, default = false }
variable "cluster_name" { type = string }
