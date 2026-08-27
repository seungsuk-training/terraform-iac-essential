resource "aws_launch_template" "web" {
  name_prefix   = "${local.name_prefix}-lt-web-"
  image_id      = var.golden_ami_id
  instance_type = var.instance_type
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.web.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${local.name_prefix}-web" })
  }
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-lt-web" })
}
resource "aws_autoscaling_group" "web" {
  name_prefix               = "${local.name_prefix}-asg-web-"
  max_size                  = 4
  min_size                  = 2
  desired_capacity          = 2
  vpc_zone_identifier       = [aws_subnet.pri_a.id, aws_subnet.pri_c.id]
  target_group_arns         = [aws_lb_target_group.web.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 60
  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }
  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-asg-web"
    propagate_at_launch = true
  }
  lifecycle { create_before_destroy = true }
}
