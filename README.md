# HA Class Access Log Dashboard on AWS

This project builds a small high-availability web service on AWS.

The service records web access logs into a private RDS MySQL database and displays recent access records through a simple dashboard. The infrastructure is managed with Terraform.

## Project Topic

HA Class Access Log Dashboard on AWS

## Main AWS Services

- Application Load Balancer
- EC2
- RDS MySQL
- Security Groups
- Terraform

## Architecture

User traffic enters through an Application Load Balancer. The ALB forwards HTTP requests to two EC2 web servers placed in different Availability Zones. Each EC2 instance runs a simple PHP dashboard application. The application stores access logs in a private RDS MySQL database.

## Project Goal

The goal of this project is to combine the AWS concepts covered in class, including EC2, ALB, RDS, Terraform, security groups, high availability, and basic service verification.

## Repository Contents

- `versions.tf`: Terraform and provider version settings
- `variables.tf`: Input variables
- `main.tf`: AWS infrastructure resources
- `outputs.tf`: Useful output values
- `user-data.sh`: EC2 bootstrap script for the dashboard app
- `command.md`: Commands and execution results
- `report.md`: Project report
- `finished.txt`: Completion summary
