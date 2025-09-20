terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = var.bucket_name
  tags = {
    Name = "MyFirstBucket"
  }
}

# -----------------------------------------------------------------------------
# VPC and Networking Resources
# -----------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name = "MyVPC"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "MyVPC_IGW"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_block
  map_public_ip_on_launch = true
  tags = {
    Name = "MyVPC_PublicSubnet"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidr_block
  tags = {
    Name = "MyVPC_PrivateSubnet"
  }
}

# -----------------------------------------------------------------------------
# Security Groups
# -----------------------------------------------------------------------------

# Security group for public nodes (swarm_manager and traefik_node)
resource "aws_security_group" "public_swarm_sg" {
  name        = "public_swarm_security_group"
  description = "Allow public SSH and Traefik ports, and internal Swarm traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Public SSH access (restrict in production)
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Public HTTP for Traefik
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Public HTTPS for Traefik
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Public Traefik dashboard
  }

  ingress {
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block] # Swarm management (internal)
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block] # Swarm node communication
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr_block] # Swarm node communication
  }

  ingress {
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr_block] # Swarm overlay network
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PublicSwarmSecurityGroup"
  }
}

# Security group for private nodes (postgres_primary and postgres_replica)
resource "aws_security_group" "private_swarm_sg" {
  name        = "private_swarm_security_group"
  description = "Allow internal SSH, Swarm, and PostgreSQL traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block] # SSH only from VPC
  }

  ingress {
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block] # Swarm management
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block] # Swarm node communication
  }

  ingress {
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr_block] # Swarm node communication
  }

  ingress {
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr_block] # Swarm overlay network
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block] # PostgreSQL internal access
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "PrivateSwarmSecurityGroup"
  }
}

# -----------------------------------------------------------------------------
# AMI Data Source
# -----------------------------------------------------------------------------

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -----------------------------------------------------------------------------
# EC2 Instances for Docker Swarm Cluster
# -----------------------------------------------------------------------------

resource "aws_instance" "swarm_manager" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.public_swarm_sg.id]
  key_name                    = "key_pair_01"
  user_data                   = <<-EOF
              #!/bin/bash
              yum update -y
              yum install docker -y
              service docker start
              usermod -a -G docker ec2-user
              chkconfig docker on
              docker swarm init
              EOF
  tags = {
    Name = "SwarmManager"
  }
}

resource "aws_instance" "traefik_node" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.public_swarm_sg.id]
  key_name                    = "key_pair_01"
  user_data                   = <<-EOF
              #!/bin/bash
              yum update -y
              yum install docker -y
              service docker start
              usermod -a -G docker ec2-user
              chkconfig docker on
              # Join the swarm (token to be added post-deployment)
              EOF
  tags = {
    Name = "TraefikNode"
  }
}

resource "aws_instance" "postgres_primary" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.private.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.private_swarm_sg.id]
  key_name                    = "key_pair_01"
  user_data                   = <<-EOF
              #!/bin/bash
              yum update -y
              yum install docker -y
              service docker start
              usermod -a -G docker ec2-user
              chkconfig docker on
              # Join the swarm (token to be added post-deployment)
              EOF
  tags = {
    Name = "PostgresPrimary"
  }
}

resource "aws_instance" "postgres_replica" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.private.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.private_swarm_sg.id]
  key_name                    = "key_pair_01"
  user_data                   = <<-EOF
              #!/bin/bash
              yum update -y
              yum install docker -y
              service docker start
              usermod -a -G docker ec2-user
              chkconfig docker on
              # Join the swarm (token to be added post-deployment)
              EOF
  tags = {
    Name = "PostgresReplica"
  }
}

# -----------------------------------------------------------------------------
# Route 53 DNS Records for Subdomains
# -----------------------------------------------------------------------------

# Data source to get the hosted zone for skyceer.com
data "aws_route53_zone" "skyceer" {
  name         = "skyceer.com"
  private_zone = false
}

# Route 53 A record for app.skyceer.com
resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.skyceer.zone_id
  name    = "app.skyceer.com"
  type    = "A"
  ttl     = 300
  records = [aws_instance.traefik_node.public_ip]
}

# Route 53 A record for primary.skyceer.com
resource "aws_route53_record" "primary" {
  zone_id = data.aws_route53_zone.skyceer.zone_id
  name    = "primary.skyceer.com"
  type    = "A"
  ttl     = 300
  records = [aws_instance.traefik_node.public_ip]
}

# Route 53 A record for replica-1.skyceer.com
resource "aws_route53_record" "replica_1" {
  zone_id = data.aws_route53_zone.skyceer.zone_id
  name    = "replica-1.skyceer.com"
  type    = "A"
  ttl     = 300
  records = [aws_instance.traefik_node.public_ip]
}
