#!/bin/bash
set -euo pipefail

exec > >(tee /var/log/access-log-dashboard-user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

dnf update -y
dnf install -y httpd php php-mysqli mariadb105

systemctl enable httpd
systemctl start httpd

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)

INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id || echo "unknown")

AVAILABILITY_ZONE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone || echo "unknown")

cat > /var/www/html/health.html <<'HEALTH'
ok
HEALTH

cat > /var/www/html/db-health.php <<'PHP'
<?php
$mysqli = new mysqli('${db_host}', '${db_username}', '${db_password}', '${db_name}', ${db_port});

if ($mysqli->connect_errno) {
    http_response_code(500);
    echo "db-error";
    exit;
}

echo "db-ok";
$mysqli->close();
?>
PHP

cat > /var/www/html/index.php <<'PHP'
<?php
$instance_id = '__INSTANCE_ID__';
$availability_zone = '__AVAILABILITY_ZONE__';
$db_host = '${db_host}';
$db_name = '${db_name}';

$client_ip = $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['REMOTE_ADDR'] ?? 'unknown';
$user_agent = $_SERVER['HTTP_USER_AGENT'] ?? 'unknown';

$mysqli = new mysqli('${db_host}', '${db_username}', '${db_password}', '${db_name}', ${db_port});

if ($mysqli->connect_errno) {
    http_response_code(500);
    echo "<h1>Database connection failed</h1>";
    echo "<p>" . htmlspecialchars($mysqli->connect_error) . "</p>";
    exit;
}

$mysqli->query("
CREATE TABLE IF NOT EXISTS access_logs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  instance_id VARCHAR(100),
  availability_zone VARCHAR(100),
  client_ip VARCHAR(100),
  user_agent TEXT
)
");

$stmt = $mysqli->prepare("INSERT INTO access_logs (instance_id, availability_zone, client_ip, user_agent) VALUES (?, ?, ?, ?)");
$stmt->bind_param("ssss", $instance_id, $availability_zone, $client_ip, $user_agent);
$stmt->execute();
$stmt->close();

$total_result = $mysqli->query("SELECT COUNT(*) AS total FROM access_logs");
$total_row = $total_result->fetch_assoc();
$total_requests = $total_row['total'];

$logs = $mysqli->query("SELECT accessed_at, instance_id, availability_zone, client_ip FROM access_logs ORDER BY id DESC LIMIT 10");
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>HA Class Access Log Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f7fb; color: #222; }
        .card { background: white; padding: 24px; margin-bottom: 20px; border-radius: 10px; border: 1px solid #ddd; }
        table { border-collapse: collapse; width: 100%; background: white; }
        th, td { border: 1px solid #ddd; padding: 10px; }
        th { background: #eef2f7; }
    </style>
</head>
<body>
    <div class="card">
        <h1>HA Class Access Log Dashboard</h1>
        <p>This page records each request into a private RDS MySQL database.</p>
        <h2>Total Requests: <?php echo htmlspecialchars($total_requests); ?></h2>
    </div>

    <div class="card">
        <h2>Current Server</h2>
        <p><strong>Instance ID:</strong> <?php echo htmlspecialchars($instance_id); ?></p>
        <p><strong>Availability Zone:</strong> <?php echo htmlspecialchars($availability_zone); ?></p>
        <p><strong>Database:</strong> Connected</p>
        <p><strong>Database Name:</strong> <?php echo htmlspecialchars($db_name); ?></p>
    </div>

    <div class="card">
        <h2>Recent Access Logs</h2>
        <table>
            <tr>
                <th>Accessed At</th>
                <th>Instance ID</th>
                <th>Availability Zone</th>
                <th>Client IP</th>
            </tr>
            <?php while ($row = $logs->fetch_assoc()) { ?>
            <tr>
                <td><?php echo htmlspecialchars($row['accessed_at']); ?></td>
                <td><?php echo htmlspecialchars($row['instance_id']); ?></td>
                <td><?php echo htmlspecialchars($row['availability_zone']); ?></td>
                <td><?php echo htmlspecialchars($row['client_ip']); ?></td>
            </tr>
            <?php } ?>
        </table>
    </div>
</body>
</html>
<?php
$mysqli->close();
?>
PHP

sed -i "s/__INSTANCE_ID__/$INSTANCE_ID/g" /var/www/html/index.php
sed -i "s/__AVAILABILITY_ZONE__/$AVAILABILITY_ZONE/g" /var/www/html/index.php

chown -R apache:apache /var/www/html
systemctl restart httpd
