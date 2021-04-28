provider "aws" {
  region = "us-east-2"
}

resource "aws_instance" "example" {
  ami           = "ami-01e7ca2ef94a0ae86"
  instance_type = "t2.micro"
  # instance_type = terraform.workspace == "default" ? "t2.nano" : "t2.micro"
}

terraform {
  backend "s3" {
    bucket     = "us-east-2-ivandock-el"
    key        = "workspaces-example/terraform.tfstate"
    region     = "us-east-2"

    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
} 
