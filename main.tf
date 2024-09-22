# main.tf
provider "aws" {
  region = var.aws_region
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "api_server" {
  ami           = data.aws_ami.ubuntu.id  # Use the ID of the latest Ubuntu AMI
  instance_type = "t2.micro"
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.api_sg.id]

  tags = {
    Name = "MetaPhoto-API-Server"
  }

  user_data = <<-EOF
              #!/bin/bash
              # Update and install dependencies
              sudo apt-get update
              sudo apt-get install -y curl
              
              # Install Node.js 20.x
              curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
              sudo apt-get install -y nodejs
              
              # Clone the repository
              git clone https://github.com/alextuadev/metaphoto-api.git /home/ubuntu/metaphoto-api
              cd /home/ubuntu/metaphoto-api
              
              # Install production dependencies
              npm install
              
              # Create .env file
              echo "PORT=80" > .env
              echo "NODE_ENV=production" >> .env
              
              # Build the project
              npm run build
              
              # Install PM2 globally
              sudo npm install -g pm2
              
              # Start the application with PM2
              pm2 start dist/server.js --name metaphoto-api
              
              # Configure PM2 to start on boot
              sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u ubuntu --hp /home/ubuntu
              pm2 save
              EOF
}

resource "aws_security_group" "api_sg" {
  name        = "metaphoto-api-security-group"
  description = "Security group for MetaPhoto API server"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# variables.tf
variable "aws_region" {
  default = "us-east-2"
}

variable "ami_id" {
  description = "The AMI to use for the EC2 instance"
  # This is an Ubuntu 20.04 LTS AMI ID for us-east-1.
  default     = "ami-0885b1f6bd170450c"
}

variable "key_name" {
  description = "The key pair name to use for the instance"
}

# outputs.tf
output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.api_server.public_ip
}

# versions.tf
terraform {
  required_version = ">= 0.12"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}