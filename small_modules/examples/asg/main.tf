terraform {
  # Require any 14.0.x version of Terraform
  required_version = ">= 0.14, < 0.15"
}

provider "aws" {
  region = "us-east-2"

  version = "~> 3.0"
}

module "asg" {
  source = "../../modules/cluster/asg-rolling-deploy"

  cluster_name  = var.cluster_name
  ami           = "ami-01e7ca2ef94a0ae86"
  instance_type = "t2.micro"

  min_size           = 1
  max_size           = 1
  enable_autoscaling = false

  subnet_ids = data.aws_subnet_ids.default.ids
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}
