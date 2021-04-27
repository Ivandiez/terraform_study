provider "aws" {
  region = "us-east-2"
}

#resource "aws_instance" "example" {
#  ami = "ami-01e7ca2ef94a0ae86"
#  instance_type = "t2.micro"
#  vpc_security_group_ids = [aws_security_group.instance.id]

  # Create simple web server with busybox default tool
#  user_data = <<-EOF
 #             #!/bin/bash
 #             echo "Hellow, world!" > index.html
 ##             nohup busybox httpd -f -p ${var.server_port} &
 #             EOF

  # Give a name to server.
#  tags = {
#  Name = "terraform-example"
#  }
#}

resource "aws_launch_configuration" "example" {
  # AMI id take from WEB console while try to create instance.
  image_id           = "ami-01e7ca2ef94a0ae86"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.instance.id]

  # Create simple web server with busybox default tool
  user_data = <<-EOF
              #!/bin/bash
              echo "Hellow, world!" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF

  # Required when using a launch configuraion with an auto scaling group.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Listen All IP addresses on port 8080
  }
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  vpc_zone_identifier = data.aws_subnet_ids.default.ids

  min_size = 2 
  max_size = 10

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

variable "server_port" {
  description = "The port the server will use for HTTP requests."
  type        = number
  default     = 8080
} 

output "public_ip" {
  value = aws_instance.example.public_ip
  description = "The public IP address of the web server."
}

resource "aws_lb" "example" {
  name        = "terraform-asg-example"
  load_balancer_type = "application"
  subnets     = data.aws_subnet_ids.default.ids
}
