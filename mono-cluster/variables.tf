variable "ssh_private_key_path" {
  description = "SSH Public key path in local machine that run Terraform"
  type = string
  sensitive = true
  default = "~/Documents/aws/key_pair_01.pem"
}

variable "key_pair_name" {
  description = "The name of key-pair SSH to connect to Ec2"
  type = string
  sensitive = true
  default = "key_pair_01"
}

variable "access_key" {
  type = string
  sensitive = true
}

variable "secret_key" {
  type = string
  sensitive = true
}

variable "region" {
  description = "Name of region"
  type        = string
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "skyceer-my-unique-bucket-name-1234"
}

# --- New variables for the VPC ---

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr_block" {
  description = "The CIDR block for the public subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr_block" {
  description = "The CIDR block for the private subnet."
  type        = string
  default     = "10.0.2.0/24"
}
