# HA Class Access Log Dashboard on AWS - Commands

## 1. Project Environment

```bash
cd /mnt/c/Dev/AWS/aws-ha-access-log-dashboard
```

This project was implemented and tested in WSL Ubuntu using Terraform and AWS CLI related tools.

## 2. Terraform Initialization

```bash
terraform init
```

Purpose:

- Initialize Terraform working directory
- Download required AWS provider
- Prepare Terraform to manage AWS resources

## 3. Terraform Format and Validation

```bash
terraform fmt
terraform validate
```

Purpose:

- Format Terraform files
- Validate Terraform syntax and configuration

## 4. Terraform Plan

```bash
terraform plan
```

Purpose:

- Preview the AWS resources that Terraform will create or update before applying changes

## 5. Terraform Apply

```bash
terraform apply
```

Purpose:

- Create the AWS resources defined in the Terraform files

Main resources created:

- Application Load Balancer
- Target Group
- Two EC2 web servers
- Private RDS MySQL database
- Security Groups for ALB, EC2, and RDS
- HTTP Listener
- Health check endpoint
- PHP access log dashboard

## 6. Terraform Output

Command:

```bash
terraform output | tee evidence/terraform-output.txt
```

Result summary:

```text
alb_dns_name = "ha-access-log-alb-1873373051.us-east-1.elb.amazonaws.com"
dashboard_url = "http://ha-access-log-alb-1873373051.us-east-1.elb.amazonaws.com/"
db_check_url = "http://ha-access-log-alb-1873373051.us-east-1.elb.amazonaws.com/db-health.php"
health_check_url = "http://ha-access-log-alb-1873373051.us-east-1.elb.amazonaws.com/health.html"

instance_ids = {
  "web-a" = "i-06b6784e3f164462f"
  "web-b" = "i-0c8e9a99dfbff92e2"
}

rds_instance_id = "ha-access-log-mysql"
rds_port = 3306
rds_publicly_accessible = false

selected_availability_zones = [
  "us-east-1a",
  "us-east-1b"
]
```

Meaning:

- The ALB DNS name was created successfully.
- Two EC2 instances were created.
- The EC2 instances were placed in two different Availability Zones.
- The RDS MySQL database was created as a private database.
- The RDS instance is not publicly accessible.

## 7. ALB Health Check Test

Command:

```bash
curl "$(terraform output -raw health_check_url)" | tee evidence/health-check.txt
```

Result:

```text
ok
```

Meaning:

- The ALB can reach the EC2 web server health check endpoint.
- The `/health.html` endpoint is working correctly.

## 8. RDS Database Connection Test

Command:

```bash
curl "$(terraform output -raw db_check_url)" | tee evidence/db-check.txt
```

Result:

```text
db-ok
```

Meaning:

- The EC2 web server can connect to the private RDS MySQL database.
- The EC2 to RDS security group rule is working correctly.

## 9. Dashboard HTTP Response Test

Command:

```bash
curl -I "$(terraform output -raw dashboard_url)" | tee evidence/dashboard-head.txt
```

Result:

```text
HTTP/1.1 200 OK
Content-Type: text/html; charset=UTF-8
Server: Apache/2.4.67 (Amazon Linux)
X-Powered-By: PHP/8.5.6
```

Meaning:

- The dashboard page is responding successfully through the ALB.
- Apache and PHP are running correctly on the EC2 web servers.

## 10. Repeated Access Test

Command:

```bash
for i in {1..5}; do
  curl -s "$(terraform output -raw dashboard_url)" | grep -E "Total Requests|Instance ID|Availability Zone|Database"
  echo
done | tee evidence/repeated-access.txt
```

Result summary:

```text
Total Requests: 12
Instance ID: i-0c8e9a99dfbff92e2
Availability Zone: us-east-1b
Database: Connected
Database Name: accesslogdb

Total Requests: 13
Instance ID: i-06b6784e3f164462f
Availability Zone: us-east-1a
Database: Connected
Database Name: accesslogdb

Total Requests: 14
Instance ID: i-0c8e9a99dfbff92e2
Availability Zone: us-east-1b
Database: Connected
Database Name: accesslogdb

Total Requests: 15
Instance ID: i-0c8e9a99dfbff92e2
Availability Zone: us-east-1b
Database: Connected
Database Name: accesslogdb

Total Requests: 16
Instance ID: i-06b6784e3f164462f
Availability Zone: us-east-1a
Database: Connected
Database Name: accesslogdb
```

Meaning:

- The total request count increased from 12 to 16.
- Both EC2 instances responded to requests.
- Requests were distributed across `us-east-1a` and `us-east-1b`.
- Each request was successfully recorded in the RDS database.

## 11. Benchmark Test

Command:

```bash
ab -l -n 100 -c 10 "$(terraform output -raw dashboard_url)" | tee evidence/ab-100-c10-dashboard.txt
```

Explanation:

- `-l`: Allow variable document length because the dashboard content changes on each request
- `-n 100`: Send 100 total requests
- `-c 10`: Send 10 concurrent requests

Result summary:

```text
Concurrency Level: 10
Time taken for tests: 4.282 seconds
Complete requests: 100
Failed requests: 0
Requests per second: 23.36 [#/sec]
Time per request: 428.172 [ms]
95% response time: 423 ms
100% longest request: 427 ms
```

Meaning:

- The ALB and EC2 web servers successfully handled 100 requests.
- There were no failed requests.
- The dashboard handled about 23.36 requests per second in this test.
- The 95% response time was 423 ms.

## 12. Cleanup Command

After final submission, AWS resources should be deleted to avoid unnecessary cost.

```bash
terraform destroy
```

Purpose:

- Delete AWS resources created by Terraform
- Remove ALB, EC2 instances, RDS instance, Target Group, Listener, and Security Groups
