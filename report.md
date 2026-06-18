# HA Class Access Log Dashboard on AWS

## 1. Project Overview

This project implements a small highly available web service on AWS.

The service is a PHP-based access log dashboard. When a user accesses the dashboard through an Application Load Balancer, one of two EC2 web servers processes the request. The web server records the request information into a private RDS MySQL database and displays recent access logs on the dashboard page.

This project was built by combining the AWS concepts covered in class, including EC2, ALB, Security Groups, Terraform, RDS, health checks, and benchmarking.

## 2. Project Objective

The main objective of this project is to build a simple AWS web service that demonstrates:

- Infrastructure as Code using Terraform
- A highly available web tier using two EC2 instances
- Public access through an Application Load Balancer
- Private database access using RDS MySQL
- Security Group based network control
- Health check verification
- Basic benchmark testing using ApacheBench

## 3. Architecture

The architecture is as follows:

```text
User Browser
    ↓
Application Load Balancer
    ↓
Target Group
    ↓
EC2 web-a         EC2 web-b
us-east-1a        us-east-1b
    ↓                 ↓
Private RDS MySQL Database
```

The user does not directly access the EC2 instances or the RDS database. The public entry point is the Application Load Balancer. The EC2 instances connect to the private RDS MySQL database to store and read access log data.

## 4. AWS Services Used

### 4.1 Terraform

Terraform was used to define and create AWS infrastructure as code.

Main Terraform files:

- `versions.tf`: Terraform and AWS provider configuration
- `variables.tf`: Input variables
- `main.tf`: AWS resource definitions
- `outputs.tf`: Output values such as ALB URL and RDS endpoint
- `terraform.tfvars.example`: Example variable file
- `.gitignore`: Excludes sensitive and auto-generated files

Terraform allowed the infrastructure to be created, updated, and deleted in a repeatable way.

### 4.2 Application Load Balancer

The Application Load Balancer receives HTTP requests from users and forwards them to healthy EC2 targets in the Target Group.

The ALB uses:

- HTTP listener on port 80
- Target Group on port 80
- Health check path `/health.html`

The dashboard URL is:

```text
http://ha-access-log-alb-1873373051.us-east-1.elb.amazonaws.com/
```

### 4.3 EC2

Two EC2 instances were created as web servers:

```text
web-a: i-06b6784e3f164462f
web-b: i-0c8e9a99dfbff92e2
```

The EC2 instances were placed in different Availability Zones:

```text
us-east-1a
us-east-1b
```

Each EC2 instance runs:

- Apache HTTP Server
- PHP
- PHP MySQL extension
- Dashboard application
- Health check page
- DB health check page

The EC2 instances are initialized using `user-data.sh`.

### 4.4 RDS MySQL

A private RDS MySQL database was created for storing access logs.

RDS configuration summary:

```text
RDS instance ID: ha-access-log-mysql
Database name: accesslogdb
Port: 3306
Publicly accessible: false
```

The RDS database is not directly accessible from the public internet. Only the EC2 security group is allowed to connect to the RDS security group on port 3306.

### 4.5 Security Groups

Three Security Groups were used.

```text
Internet → ALB Security Group: HTTP 80
ALB Security Group → EC2 Security Group: HTTP 80
EC2 Security Group → RDS Security Group: MySQL 3306
```

This structure separates public access, web server access, and database access.

The RDS database is protected because it is not publicly accessible and only accepts MySQL traffic from the EC2 web servers.

## 5. Application Logic

The dashboard application works as follows:

```text
1. User accesses the ALB URL.
2. ALB forwards the request to one healthy EC2 instance.
3. EC2 runs the PHP dashboard page.
4. PHP connects to the private RDS MySQL database.
5. PHP creates the access_logs table if it does not exist.
6. PHP inserts the current request information into the database.
7. PHP reads recent access logs from the database.
8. Dashboard displays total requests, current server information, database status, and recent logs.
```

The access log table stores:

- Access time
- EC2 instance ID
- Availability Zone
- Client IP address
- User agent

## 6. Verification Results

### 6.1 Terraform Output

Terraform output confirmed that the main AWS resources were created successfully.

Key output values:

```text
ALB DNS: ha-access-log-alb-1873373051.us-east-1.elb.amazonaws.com
RDS instance ID: ha-access-log-mysql
RDS publicly accessible: false
Selected Availability Zones: us-east-1a, us-east-1b
```

This confirms that the project created an ALB, two EC2 instances, and a private RDS MySQL database.

### 6.2 Health Check Test

Command:

```bash
curl "$(terraform output -raw health_check_url)"
```

Result:

```text
ok
```

The health check endpoint worked successfully.

### 6.3 Database Connection Test

Command:

```bash
curl "$(terraform output -raw db_check_url)"
```

Result:

```text
db-ok
```

This confirms that the EC2 web server can connect to the private RDS MySQL database.

### 6.4 Dashboard HTTP Test

Command:

```bash
curl -I "$(terraform output -raw dashboard_url)"
```

Result:

```text
HTTP/1.1 200 OK
```

This confirms that the dashboard page is accessible through the ALB.

### 6.5 Repeated Access Test

Repeated access showed that the total request count increased from 12 to 16. The responses came from both EC2 instances:

```text
i-0c8e9a99dfbff92e2 in us-east-1b
i-06b6784e3f164462f in us-east-1a
```

This confirms that:

- Requests are recorded into RDS.
- ALB distributes requests to both EC2 instances.
- Both Availability Zones are used.

### 6.6 Benchmark Test

ApacheBench was used to test the dashboard.

Command:

```bash
ab -l -n 100 -c 10 "$(terraform output -raw dashboard_url)"
```

The `-l` option was used because the dashboard page changes dynamically on each request.

Result summary:

```text
Complete requests: 100
Failed requests: 0
Requests per second: 23.36
Time per request: 428.172 ms
95% response time: 423 ms
Longest request: 427 ms
```

The benchmark completed successfully with no failed requests.

## 7. Relation to Class Contents

This project is based on the AWS topics covered in class.

Class concepts used:

- EC2 web server
- Application Load Balancer
- Target Group
- Health Check
- Security Group
- Terraform Infrastructure as Code
- RDS MySQL
- Benchmark testing

The project extends the previous EC2/RDS lab concept by replacing WordPress with a custom PHP access log dashboard. The infrastructure pattern is similar to the class labs, but the application logic was changed to record and display access logs.

## 8. What Was Implemented

Implemented features:

- Terraform-based AWS infrastructure
- Two EC2 web servers in different Availability Zones
- Public Application Load Balancer
- HTTP listener and Target Group
- ALB health check endpoint
- Private RDS MySQL database
- EC2 to RDS database connection
- PHP access log dashboard
- Request logging into MySQL
- Recent access log display
- Repeated access verification
- ApacheBench benchmark test

## 9. Limitations and Future Improvements

Current limitations:

- EC2 instances are fixed at two servers.
- Auto Scaling Group is not implemented.
- HTTPS is not configured.
- CloudWatch alarm-based scaling is not implemented.
- RDS Multi-AZ is not enabled.
- Database password is handled through Terraform variables.

Future improvements:

- Replace fixed EC2 instances with an Auto Scaling Group.
- Add CloudWatch alarms for CPU or request count based scaling.
- Configure HTTPS using ACM and ALB listener on port 443.
- Enable RDS Multi-AZ for stronger database availability.
- Store database credentials in AWS Secrets Manager.
- Enable ALB access logs to S3.
- Add CloudWatch dashboard for monitoring.

## 10. Conclusion

This project successfully demonstrates a small highly available AWS web service using Terraform, ALB, EC2, and private RDS MySQL.

The ALB distributes traffic to two EC2 instances in different Availability Zones. The EC2 web servers run a PHP dashboard and store request logs in a private RDS MySQL database. Health check, database connection check, repeated access test, and benchmark test confirmed that the application and infrastructure are working correctly.

The project shows how AWS infrastructure can be defined as code and how web, load balancing, and database layers can be separated in a cloud-based architecture.
