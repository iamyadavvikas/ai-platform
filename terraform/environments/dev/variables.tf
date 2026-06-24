variable "environment" { type = string }
variable "region" { type = string }
variable "vpc_cidr" { type = string }
variable "cluster_name" { type = string }
variable "enable_gpu" { type = bool, default = true }
variable "gpu_min_size" { type = number, default = 0 }
variable "gpu_max_size" { type = number, default = 2 }
variable "gpu_instance_type" { type = string, default = "g5.xlarge" }
variable "cpu_instance_type" { type = string, default = "t3.large" }
variable "cpu_min_size" { type = number, default = 1 }
variable "cpu_max_size" { type = number, default = 4 }
