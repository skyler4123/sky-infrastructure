terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region     = var.region
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

# Create a route table for the public subnet to route traffic to the internet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # The route to the internet gateway for 0.0.0.0/0 traffic
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "MyVPC_PublicRouteTable"
  }
}

# Associate the route table with the public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
# -----------------------------------------------------------------------------
# Security Groups
# -----------------------------------------------------------------------------

# Security group for public nodes (ssh_tunnel and traefik_node)
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

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    # cidr_blocks = [var.vpc_cidr_block] # PostgreSQL internal access
    cidr_blocks = ["0.0.0.0/0"]
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

data "aws_ami" "ubuntu_22_04_lts" {
  most_recent = true

  # Official Canonical Owner ID for Ubuntu AMIs. Always use this ID for official, trusted images.
  owners = ["099720109477"]

  filter {
    name = "name"
    # Pattern for the standard, EBS-backed, HVM, 64-bit (amd64) server image.
    # 'jammy' is the codename for Ubuntu 22.04. The '*' ensures you get the latest date-stamped release.
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
# -----------------------------------------------------------------------------
# EC2 Instances for Docker Swarm Cluster
# -----------------------------------------------------------------------------
resource "aws_instance" "ssh_tunnel_ubuntu" {
  ami                         = data.aws_ami.ubuntu_22_04_lts.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.public_swarm_sg.id]
  key_name                    = var.key_pair_name
  user_data                   = <<-EOF
   #!/bin/bash
   # Set GatewayPorts to 'yes' in sshd_config and restart the service
   # This allows remote forwarded ports to be bound to non-loopback addresses (0.0.0.0)
   SSHD_CONFIG_FILE="/etc/ssh/sshd_config"
   # Use sed to ensure 'GatewayPorts yes' is set. 
   # The 's/^#GatewayPorts.*/GatewayPorts yes/' part uncomments and sets it if it exists
   # The 't' jumps to end of script if a substitution was made
   # The '$aGatewayPorts yes' adds it to the end if not found
   sudo sed -i -e '/^#GatewayPorts/d' -e '/^GatewayPorts/d' $SSHD_CONFIG_FILE
   echo "GatewayPorts yes" | sudo tee -a /etc/ssh/sshd_config
   # Restart sshd service to apply the new configuration
   systemctl restart sshd
   EOF

  tags = {
    Name = "SSH Tunnel Ubuntu"
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

# Route 53 A record for skyceer.com
resource "aws_route53_record" "default" {
  zone_id = data.aws_route53_zone.skyceer.zone_id
  name    = "skyceer.com"
  type    = "A"
  ttl     = 300
  records = [aws_instance.ssh_tunnel_ubuntu.public_ip]
}

# Route 53 A record for app.skyceer.com
resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.skyceer.zone_id
  name    = "app.skyceer.com"
  type    = "A"
  ttl     = 300
  records = [aws_instance.ssh_tunnel_ubuntu.public_ip]
}

# Route 53 A record for primary.skyceer.com
resource "aws_route53_record" "primary" {
  zone_id = data.aws_route53_zone.skyceer.zone_id
  name    = "primary.skyceer.com"
  type    = "A"
  ttl     = 300
  records = [aws_instance.ssh_tunnel_ubuntu.public_ip]
}

# Route 53 A record for replica-1.skyceer.com
resource "aws_route53_record" "replica_1" {
  zone_id = data.aws_route53_zone.skyceer.zone_id
  name    = "replica-1.skyceer.com"
  type    = "A"
  ttl     = 300
  records = [aws_instance.ssh_tunnel_ubuntu.public_ip]
}
