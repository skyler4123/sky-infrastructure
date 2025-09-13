variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "skyceer-my-unique-bucket-name-123"
}

variable "access_key" {
  type = string
  sensitive = true
}

variable "secret_key" {
  type = string
  sensitive = true
}