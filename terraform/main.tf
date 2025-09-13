terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_s3_bucket" "my_bucket" {
  # bucket = "my-unique-bucket-name-123" # Must be globally unique
  bucket = var.bucket_name
  tags = {
    Name = "MyFirstBucket"
  }
}

# -----------------------------------------------------------------------------
# New VPC and Networking Resources
# -----------------------------------------------------------------------------

# Create a new Virtual Private Cloud (VPC)
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = "MyVPC"
  }
}

# Create an Internet Gateway (IGW) for the VPC
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "MyVPC_IGW"
  }
}