#!/bin/bash -ex
# Updated to use Amazon Linux 2023
dnf update -y
dnf install -y httpd wget php-fpm php-mysqli php-json php php-devel
dnf install -y mariadb105-server
/usr/bin/systemctl enable httpd
/usr/bin/systemctl start httpd
cd /var/www/html
wget https://aws-largeobjects.s3.ap-northeast-2.amazonaws.com/AWS-AcademyACF/lab7-app-php7.zip
unzip lab7-app-php7.zip -d /var/www/html/
chown -R apache:root /var/www/html
