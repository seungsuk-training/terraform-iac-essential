#!/bin/bash -ex
# Amazon Linux 2023 Golden AMI bootstrap
dnf update -y
dnf install -y httpd wget unzip curl php-fpm php-mysqli php-json php php-devel
dnf install -y mariadb105-server

cd /var/www/html
wget -O /tmp/lab7-app-php7.zip \
  https://aws-largeobjects.s3.ap-northeast-2.amazonaws.com/AWS-AcademyACF/lab7-app-php7.zip
unzip -oq /tmp/lab7-app-php7.zip -d /var/www/html/
rm -f /tmp/lab7-app-php7.zip

# The original lab app uses ec2-metadata. Replace it with an IMDSv2-compatible page
# because Amazon Linux 2023 requires IMDSv2 by default.
cat > /var/www/html/get-index-meta-data.php <<'PHP'
<?php
function get_instance_metadata($path) {
    $token = trim(shell_exec(
        "curl -sS --fail --max-time 2 -X PUT " .
        "-H 'X-aws-ec2-metadata-token-ttl-seconds: 21600' " .
        "http://169.254.169.254/latest/api/token 2>/dev/null"
    ));

    if ($token === '') {
        return 'Unavailable';
    }

    $header = escapeshellarg('X-aws-ec2-metadata-token: ' . $token);
    $url = escapeshellarg('http://169.254.169.254/latest/meta-data/' . $path);
    $value = trim(shell_exec(
        "curl -sS --fail --max-time 2 -H {$header} {$url} 2>/dev/null"
    ));

    return $value === '' ? 'Unavailable' : $value;
}

$instance_id = htmlspecialchars(get_instance_metadata('instance-id'), ENT_QUOTES, 'UTF-8');
$az = htmlspecialchars(get_instance_metadata('placement/availability-zone'), ENT_QUOTES, 'UTF-8');

echo "<table class='table table-bordered'>";
echo "<tr><th>Meta-Data</th><th>Value</th></tr>";
echo "<tr><td>Instance ID</td><td><i>{$instance_id}</i></td></tr>";
echo "<tr><td>Availability Zone</td><td><i>{$az}</i></td></tr>";
echo "</table>";
?>
PHP

chown -R apache:root /var/www/html
systemctl enable --now php-fpm
systemctl enable --now httpd
