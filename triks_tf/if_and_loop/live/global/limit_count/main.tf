provider "aws" {
  region = "us-east-2"
}

resource "aws_instance" "example_1" {
  count         = 3
  ami           = "ami-01e7ca2ef94a0ae86"
  instance_type = "t2.micro"
}

resource "aws_instance" "example_2" {
  count             = length(data.aws_availability_zones.all.names)
  availability_zone = data.aws_availability_zones.all.names[count.index]
  ami               = "ami-01e7ca2ef94a0ae86"
  instance_type     = "t2.micro"
}

resource "random_integer" "num_instances" {
  min = 1
  max = 3
}

resource "aws_instance" "example_3" {
  count         = random_integer.num_instances.result
  ami           = "ami-01e7ca2ef94a0ae86"
  instance_type = "t2.micro" 
}

data "aws_availability_zones" "all" {}
