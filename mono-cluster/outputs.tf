# S3 Bucket Outputs
output "s3_bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.my_bucket.bucket
}

# VPC Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

# Subnet Outputs
output "public_subnet_id" {
  description = "The ID of the public subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "The ID of the private subnet"
  value       = aws_subnet.private.id
}

# Security Group Outputs
output "public_swarm_sg_id" {
  description = "The ID of the public swarm security group"
  value       = aws_security_group.public_swarm_sg.id
}

output "private_swarm_sg_id" {
  description = "The ID of the private swarm security group"
  value       = aws_security_group.private_swarm_sg.id
}

# EC2 Instance Outputs
output "swarm_manager_instance_id" {
  description = "The ID of the Swarm Manager EC2 instance"
  value       = aws_instance.swarm_manager.id
}

output "swarm_manager_public_ip" {
  description = "The public IP of the Swarm Manager EC2 instance"
  value       = aws_instance.swarm_manager.public_ip
}

# Route 53 Outputs
output "app_dns_name" {
  description = "The DNS name for app.skyceer.com"
  value       = aws_route53_record.app.name
}

output "primary_dns_name" {
  description = "The DNS name for primary.skyceer.com"
  value       = aws_route53_record.primary.name
}
