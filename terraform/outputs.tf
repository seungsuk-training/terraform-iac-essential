output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.web.dns_name
}
output "alb_url" {
  description = "URL used to verify the highly available web service"
  value       = "http://${aws_lb.web.dns_name}"
}
