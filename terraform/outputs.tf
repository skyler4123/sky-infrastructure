#
# Output values for the created resources.
# These can be used by other configurations or for quick reference.
#

# --- Your S3 bucket output ---

output "bucket_name" {
  description = "The name of the created S3 bucket."
  value       = aws_s3_bucket.my_bucket.bucket
}

# --- New VPC outputs ---

output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "The ID of the public subnet."
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "The ID of the private subnet."
  value       = aws_subnet.private.id
}

output "public_subnet_cidr" {
  description = "The CIDR block of the public subnet."
  value       = aws_subnet.public.cidr_block
}

output "private_subnet_cidr" {
  description = "The CIDR block of the private subnet."
  value       = aws_subnet.private.cidr_block
}
