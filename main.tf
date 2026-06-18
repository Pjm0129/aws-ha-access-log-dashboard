# Default VPC and subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_vpc" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "default_vpc" {
  for_each = toset(data.aws_subnets.default_vpc.ids)

  id = each.value
}

# Latest Amazon Linux 2023 AMI
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Select two subnets from different Availability Zones
locals {
  common_tags = {
    Project = "ha-class-access-log-dashboard"
    Course  = "cloud-computing-aws"
  }

  subnets_by_az = {
    for subnet in data.aws_subnet.default_vpc : subnet.availability_zone => subnet.id...
  }

  selected_azs = slice(sort(keys(local.subnets_by_az)), 0, 2)

  selected_subnet_ids = [
    for az in local.selected_azs : sort(local.subnets_by_az[az])[0]
  ]

  instance_subnet_map = zipmap(["web-a", "web-b"], local.selected_subnet_ids)
}

# Security group for the public Application Load Balancer
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "ALB HTTP access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from public"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.http_cidr]
  }

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-alb-sg"
  })
}

# Security group for EC2 web servers
resource "aws_security_group" "ec2" {
  name        = "${var.name_prefix}-ec2-sg"
  description = "EC2 web access from ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  dynamic "ingress" {
    for_each = var.enable_ssh ? [1] : []

    content {
      description = "SSH access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.ssh_cidr]
    }
  }

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-ec2-sg"
  })
}

# Security group for private RDS MySQL
resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "RDS MySQL access from EC2"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "MySQL from EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-rds-sg"
  })
}

# RDS subnet group
resource "aws_db_subnet_group" "access_log" {
  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = local.selected_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-db-subnets"
  })
}

# Private RDS MySQL for access log storage
resource "aws_db_instance" "access_log" {
  identifier             = "${var.name_prefix}-mysql"
  engine                 = "mysql"
  instance_class         = var.db_instance_class
  allocated_storage      = var.db_allocated_storage
  db_name                = var.db_name
  username               = var.db_master_username
  password               = var.db_master_password
  db_subnet_group_name   = aws_db_subnet_group.access_log.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  skip_final_snapshot    = true
  deletion_protection    = false
  apply_immediately      = true

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-mysql"
  })
}

# EC2 web servers
resource "aws_instance" "web" {
  for_each = local.instance_subnet_map

  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = each.value
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = true
  key_name                    = var.key_name
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/user-data.sh", {
    db_host     = aws_db_instance.access_log.address
    db_port     = aws_db_instance.access_log.port
    db_name     = var.db_name
    db_username = var.db_master_username
    db_password = var.db_master_password
  })

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-${each.key}"
  })
}

# Target group for EC2 web servers
resource "aws_lb_target_group" "web" {
  name        = "${var.name_prefix}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/health.html"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-tg"
  })
}

# Attach EC2 instances to the target group
resource "aws_lb_target_group_attachment" "web" {
  for_each = aws_instance.web

  target_group_arn = aws_lb_target_group.web.arn
  target_id        = each.value.id
  port             = 80
}

# Public Application Load Balancer
resource "aws_lb" "web" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.selected_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-alb"
  })
}

# HTTP listener for ALB
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
