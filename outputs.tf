output "alb_dns_name" {
  value = aws_lb.web.dns_name
}

output "dashboard_url" {
  value = "http://${aws_lb.web.dns_name}/"
}

output "health_check_url" {
  value = "http://${aws_lb.web.dns_name}/health.html"
}

output "db_check_url" {
  value = "http://${aws_lb.web.dns_name}/db-health.php"
}

output "instance_ids" {
  value = {
    for name, instance in aws_instance.web : name => instance.id
  }
}

output "instance_public_ips" {
  value = {
    for name, instance in aws_instance.web : name => instance.public_ip
  }
}

output "instance_public_dns" {
  value = {
    for name, instance in aws_instance.web : name => instance.public_dns
  }
}

output "rds_endpoint" {
  value = aws_db_instance.access_log.address
}

output "rds_instance_id" {
  value = aws_db_instance.access_log.identifier
}

output "rds_port" {
  value = aws_db_instance.access_log.port
}

output "rds_publicly_accessible" {
  value = aws_db_instance.access_log.publicly_accessible
}

output "selected_availability_zones" {
  value = local.selected_azs
}

output "selected_subnet_ids" {
  value = local.selected_subnet_ids
}

output "security_group_ids" {
  value = {
    alb = aws_security_group.alb.id
    ec2 = aws_security_group.ec2.id
    rds = aws_security_group.rds.id
  }
}

output "target_group_arn" {
  value = aws_lb_target_group.web.arn
}
