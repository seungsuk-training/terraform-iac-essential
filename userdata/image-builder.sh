#!/bin/bash -ex
dnf update -y
dnf install -y httpd
cat > /var/www/html/index.html <<'HTML'
<!doctype html>
<html lang="ko">
<head><meta charset="utf-8"><title>Terraform IaC Essential</title></head>
<body><h1>Terraform IaC Essential</h1><p>Golden AMI 기반 Web Server가 정상적으로 실행 중입니다.</p></body>
</html>
HTML
systemctl enable --now httpd
