variable "access_key" {
  type = string
  sensitive = true
}

variable "secret_key" {
  type = string
  sensitive = true
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