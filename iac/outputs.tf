# --- Outputs
output "alb_url" {
  description = "ALB URL"
  value       = "http://${aws_lb.app.dns_name}"
}

output "instance_public_ip" {
  value = aws_instance.app.public_ip
}
