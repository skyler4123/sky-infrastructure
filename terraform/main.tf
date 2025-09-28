terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    # NOTE: The external data source requires the 'external' provider
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
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

# Generic user_data for all worker nodes
locals {
  setup_docker_script = <<-EOF
     #!/bin/bash
     yum update -y
     yum install -y docker
     service docker start
     usermod -a -G docker ec2-user
     chkconfig docker on
     EOF
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
  key_name                    = var.key_pair_name
  user_data                   = <<-EOF
    ${local.setup_docker_script}
    
    # Fetch the private IP dynamically
    PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
    
    # Initialize Docker Swarm with the private IP
    docker swarm init --advertise-addr $PRIVATE_IP
    EOF

  tags = {
    Name = "SwarmManager"
  }
}

# --- DYNAMICALLY RETRIEVE SWARM WORKER TOKEN ---
# resource "null_resource" "swarm_join_token" {
#   depends_on = [aws_instance.swarm_manager]

#   triggers = {
#     # This dummy trigger ensures the provisioner runs when the IP changes
#     manager_public_ip = aws_instance.swarm_manager.public_ip
#   }
  
#   provisioner "local-exec" {
#     # Replace the connection and remote-exec with this local-exec to handle the SSH command
#     command = <<-EOT
#       echo "Waiting for manager to initialize Swarm..."
#       sleep 30

#       MANAGER_IP="${self.triggers.manager_public_ip}"
#       TOKEN_PATH="${var.docker_swarm_join_token_path}"
      
#       # SSH to manager, get the token, and write it to a local file
#       WORKER_TOKEN=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.ssh_private_key_path} ec2-user@$MANAGER_IP "docker swarm join-token worker -q")
      
#       if [ -z "$WORKER_TOKEN" ]; then
#         echo "Failed to retrieve worker token!"
#         exit 1
#       fi
      
#       # Write the token to the local file
#       echo "$WORKER_TOKEN" > $TOKEN_PATH
#       echo "Swarm token saved to $TOKEN_PATH"
#     EOT
#   }
# }
# This external data source executes a local command (SSH) to the manager,
# gets the worker token, and exposes it as a variable for the worker user_data.
data "external" "swarm_worker_token" {
  # Depends on the manager instance being up and the swarm initialized
  depends_on = [aws_instance.swarm_manager]

  program = ["bash", "-c", <<-EOT
    MANAGER_IP="${aws_instance.swarm_manager.public_ip}"
    SSH_KEY_PATH="${var.ssh_private_key_path}"
    
    echo "Waiting 30 seconds for Swarm Manager to initialize..." >&2
    sleep 30
    
    # SSH to the manager and retrieve the worker join token
    # We retrieve the full command, not just the token, for flexibility
    JOIN_COMMAND=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $SSH_KEY_PATH ec2-user@$MANAGER_IP "docker swarm join-token worker --quiet")
    
    if [ -z "$JOIN_COMMAND" ]; then
      echo "Failed to retrieve worker token!" >&2
      exit 1
    fi
    
    # Output the token as JSON for Terraform to consume
    echo "{\"token\": \"$JOIN_COMMAND\"}"
  EOT
  ]
}

resource "aws_instance" "traefik_node" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.public_swarm_sg.id]
  key_name                    = var.key_pair_name
  # --- UPDATED USER_DATA TO JOIN SWARM AT BOOT ---
  user_data                   = <<-EOF
    ${local.setup_docker_script}
    
    # Manager Private IP for Swarm communication (available via resource reference)
    MANAGER_PRIVATE_IP="${aws_instance.swarm_manager.private_ip}"
    
    # Swarm Worker Join Token (retrieved via external data source)
    WORKER_TOKEN="${data.external.swarm_worker_token.result.token}"
    
    # Join the swarm using the token and the manager's private IP
    # The full command is docker swarm join --token <token> <manager_ip>:2377
    docker swarm join --token $WORKER_TOKEN $MANAGER_PRIVATE_IP:2377
    EOF
  # ----------------------------------------------
  depends_on                  = [aws_instance.swarm_manager]
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
  key_name                    = var.key_pair_name
  # --- UPDATED USER_DATA TO JOIN SWARM AT BOOT ---
  user_data                   = <<-EOF
    ${local.setup_docker_script}
    
    # Manager Private IP for Swarm communication (available via resource reference)
    MANAGER_PRIVATE_IP="${aws_instance.swarm_manager.private_ip}"
    
    # Swarm Worker Join Token (retrieved via external data source)
    WORKER_TOKEN="${data.external.swarm_worker_token.result.token}"
    
    # Join the swarm using the token and the manager's private IP
    # The full command is docker swarm join --token <token> <manager_ip>:2377
    docker swarm join --token $WORKER_TOKEN $MANAGER_PRIVATE_IP:2377
    EOF
  # ----------------------------------------------
  depends_on                  = [aws_instance.swarm_manager]
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
  key_name                    = var.key_pair_name
  # --- UPDATED USER_DATA TO JOIN SWARM AT BOOT ---
  user_data                   = <<-EOF
    ${local.setup_docker_script}
    
    # Manager Private IP for Swarm communication (available via resource reference)
    MANAGER_PRIVATE_IP="${aws_instance.swarm_manager.private_ip}"
    
    # Swarm Worker Join Token (retrieved via external data source)
    WORKER_TOKEN="${data.external.swarm_worker_token.result.token}"
    
    # Join the swarm using the token and the manager's private IP
    # The full command is docker swarm join --token <token> <manager_ip>:2377
    docker swarm join --token $WORKER_TOKEN $MANAGER_PRIVATE_IP:2377
    EOF
  # ----------------------------------------------
  depends_on                  = [aws_instance.swarm_manager]
  tags = {
    Name = "PostgresReplica"
  }
}

# -----------------------------------------------------------------------------
# Null Resource to Orchestrate Swarm Join via SSH
# -----------------------------------------------------------------------------

# The following commented block is now largely redundant since the worker nodes
# join automatically via user_data, but it remains here for reference.
# resource "null_resource" "swarm_cluster_joiner" {

  # # This ensures the provisioner only runs after all instances are created.
  # depends_on = [
  #   aws_instance.swarm_manager,
  #   aws_instance.traefik_node,
  #   aws_instance.postgres_primary,
  #   aws_instance.postgres_replica
  # ]

  # # SSH connection details for the manager node
  # connection {
  #   type        = "ssh"
  #   user        = "ec2-user"
  #   private_key = file(var.ssh_private_key_path)
  #   host        = aws_instance.swarm_manager.public_ip
  # }

  # # This provisioner runs a script on YOUR local machine (where you run terraform apply)
  # provisioner "local-exec" {
  #   command = <<-EOF
  #      echo "Waiting for Docker to be fully initialized on all nodes..."
  #      sleep 45
 
  #      echo "Fetching Swarm token from manager..."
  #      WORKER_TOKEN=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.ssh_private_key_path} ec2-user@${aws_instance.swarm_manager.public_ip} 'docker swarm join-token worker -q')
 
  #      if [ -z "$WORKER_TOKEN" ]; then
  #        echo "Failed to retrieve worker token!"
  #        exit 1
  #      fi
 
  #      echo "Token retrieved. Joining worker nodes to the swarm..."
 
  #      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.ssh_private_key_path} ec2-user@${aws_instance.traefik_node.public_ip} "docker swarm join --token $WORKER_TOKEN ${aws_instance.swarm_manager.private_ip}:2377"
  #      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.ssh_private_key_path} ec2-user@${aws_instance.postgres_primary.private_ip} "docker swarm join --token $WORKER_TOKEN ${aws_instance.swarm_manager.private_ip}:2377"
  #      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.ssh_private_key_path} ec2-user@${aws_instance.postgres_replica.private_ip} "docker swarm join --token $WORKER_TOKEN ${aws_instance.swarm_manager.private_ip}:2377"
 
  #      echo "All nodes have attempted to join the swarm."
  #    EOF
  # }
# }

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
