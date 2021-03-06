resource "aws_launch_configuration" "example" {
  # AMI id take from WEB console while try to create instance.
  image_id        = var.ami #"ami-01e7ca2ef94a0ae86"
  instance_type   = var.instance_type  #"t2.micro"
  security_groups = [aws_security_group.instance.id]

  # Create simple web server with busybox default tool
  user_data       = var.user_data #data.template_file.user_data.rendered

  # Required when using a launch configuraion with an auto scaling group.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  # Explicitly depend on the launch configuraion's name so each time it's
  # replaced, this ASG is also replaced.
  name = "${var.cluster_name}-${aws_launch_configuration.example.name}"  

  launch_configuration = aws_launch_configuration.example.name
  vpc_zone_identifier = var.subnet_ids # data.aws_subnet_ids.default.ids

  target_group_arns = var.target_group_arns # [aws_lb_target_group.asg.arn]
  health_check_type = var.health_check_type # "ELB"

  min_size = var.min_size # 2 
  max_size = var.max_size # 10

  # Wait for at least this many instances to pass health checks before
  # considering the ASG deployment complete.
  min_elb_capacity = var.min_size

  # When replacing this ASG, create the replacement first, and only delete the
  # original after.
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = var.cluster_name
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = {
      for key, value in var.custom_tags:
        key => upper(value)
      if key != "Name"
    }

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
  count = var.enable_autoscaling ? 1 : 0

  scheduled_action_name  = "${var.cluster_name}-scale-out-during-business-hours"
  min_size               = 2
  max_size               = 10
  desired_capacity       = 10
  recurrence             = "0 9 * * *"
  autoscaling_group_name = aws_autoscaling_group.example.name
}

resource "aws_autoscaling_schedule" "scale_in_at_night" {
  count = var.enable_autoscaling ? 1 : 0

  scheduled_action_name  = "${var.cluster_name}-scale-in-at-night"
  min_size               = 2
  max_size               = 10
  desired_capacity       = 2
  recurrence             = "0 17 * * *"
  autoscaling_group_name = aws_autoscaling_group.example.name
}

resource "aws_security_group" "instance" {
  name = "${var.cluster_name}-instance"
}

resource "aws_security_group_rule" "allow_server_http_inbound" {
    type        = "ingress"
    security_group_id = aws_security_group.instance.id
    
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = local.tcp_protocol
    cidr_blocks = local.all_ips # Listen All IP addresses on port 8080
}
resource "aws_cloudwatch_metric_alarm" "high_cpu_utilization" {
  alarm_name  = "${var.cluster_name}-high-cpu-utilization"
  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.example.name
  }

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  period              = 300
  statistic           = "Average"
  threshold           = 90
  unit                = "Percent"
}

resource "aws_cloudwatch_metric_alarm" "low_cpu_credit_balance" {
  count = format("%.1s", var.instance_type) == "t" ? 1 : 0

  alarm_name  = "${var.cluster_name}-low-cpu-credit-balance"
  namespace   = "AWS/EC2"
  metric_name = "CPUCreditBalance"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.example.name
  }

  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  period              = 300
  statistic           = "Minimum"
  threshold           = 10
  unit                = "Count"
}

locals {
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
}
