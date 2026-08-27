variable "aws_region" {
  description = "AWS Region used for this lab"
  type        = string
  default     = "ap-northeast-2"
}
variable "project_name" {
  description = "Project name used in resource names and tags"
  type        = string
  default     = "terraform-iac-essential"
}
variable "golden_ami_id" {
  description = "AMI ID created manually from the Image Builder EC2 instance"
  type        = string
  validation {
    condition     = can(regex("^ami-[0-9a-f]+$", var.golden_ami_id))
    error_message = "golden_ami_id must be a valid AMI ID such as ami-0123456789abcdef0."
  }
}
variable "instance_type" {
  description = "EC2 instance type used by the Launch Template"
  type        = string
  default     = "t3.micro"
}
locals {
  name_prefix = "${var.project_name}-lab"
  common_tags = {
    Project     = var.project_name
    Environment = "lab"
    ManagedBy   = "Terraform"
  }
}
