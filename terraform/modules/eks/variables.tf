variable "environment" { type = string }
variable "cluster_name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "cpu_instance_type" { type = string, default = "t3.large" }
variable "gpu_instance_type" { type = string, default = "g5.xlarge" }
variable "gpu_min_size" { type = number, default = 0 }
variable "gpu_max_size" { type = number, default = 4 }
variable "gpu_desired_size" { type = number, default = 0 }
variable "gpu_node_instance_profile" { type = string }
