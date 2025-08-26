terraform {
  required_version = ">= 1.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# --- Default VPC & subnets (keeps template small)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# --- Security Groups
# ALB: allow HTTP :80 from Internet
resource "aws_security_group" "alb_sg" {
  name        = "${var.name}-alb-sg"
  description = "ALB SG"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description      = "HTTP from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = { Name = "${var.name}-alb-sg" }
}

# EC2: allow :80 from ALB only (+ optional SSH)
resource "aws_security_group" "ec2_sg" {
  name        = "${var.name}-ec2-sg"
  description = "EC2 SG"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "App port from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  dynamic "ingress" {
    for_each = var.ssh_key_name == "" ? [] : [var.ssh_key_name]
    content {
      description = "SSH (optional)"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = { Name = "${var.name}-ec2-sg" }
}

# --- ALB + listener + target group (targets port 80 on instance)
resource "aws_lb" "app" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids
  tags               = { Name = "${var.name}-alb" }
}

resource "aws_lb_target_group" "app_tg" {
  name        = "${var.name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "${var.name}-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# --- AMI (Amazon Linux 2023)
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"] # Amazon

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Optional key pair for SSH
resource "tls_private_key" "dev_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = var.ssh_key_name
  public_key = tls_private_key.dev_key.public_key_openssh

  provisioner "local-exec" { # Generate "terraform-key-pair.pem" in current directory
    command = <<-EOT
      echo '${tls_private_key.dev_key.private_key_pem}' > ./'${var.ssh_key_name}'.pem
      chmod 400 ./'${var.ssh_key_name}'.pem
    EOT
  }
}

# --- EC2 instance
resource "aws_instance" "app" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = element(data.aws_subnets.default.ids, 0)
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  key_name                    = aws_key_pair.generated_key.key_name
  associate_public_ip_address = true
  # key_name                    = length(aws_key_pair.generated_key) == 0 ? null : aws_key_pair.generated_key[0].key_name

  user_data = <<-EOF
#!/bin/bash
set -eux

sudo su

# Update & tools
dnf -y update
dnf -y install git curl --allowerasing

# Install uv (https://astral.sh/uv)
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="/root/.cargo/bin:$PATH"

# App directory
cd /opt

# Clone your repo (replace with your URL)
git clone ${var.github_repo_url} app
cd app

# Copy systemd service script
cp iac/user_data/fastapi.service /etc/systemd/system/fastapi.service

# Dependency sync (uses pyproject.toml + uv.lock)
uv sync --frozen --no-cache
cd app

systemctl daemon-reload
systemctl enable --now fastapi.service
systemctl start fastapi.service
EOF

  tags = { Name = "${var.name}-ec2" }
}

# Attach instance to target group (port 80)
resource "aws_lb_target_group_attachment" "app_attach" {
  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.app.id
  port             = 80
}
