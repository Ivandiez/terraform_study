provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "example" {
  # AMI id take from WEB console while try to create instance.
  ami           = "ami-013f17f36f8b1fefb"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id]

  # Create simple web server with busybox default tool
  user_data = <<-EOF
              #!/bin/bash
              echo "Hellow, world!" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF

  # Give a name to server.
  tags = {
    Name = "terraform-example"
  }
}

resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Listen All IP addresses on port 8080
  }
} 
