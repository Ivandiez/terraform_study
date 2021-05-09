terraform {
  required_version = ">= 0.14, < 0.15"
}

provider "aws" {
  region = "us-east-2"

  version = "~> 3.0"
}

terraform {
  backend "s3" {
    bucket      = "us-east-2-ivandock-el"
    key         = "stage/data-stores/mysql/terraform.tfstate"
    region      = "us-east-2"

    dynamodb_table  = "terraform-up-and-running-locks"
    encrypt         = true
  }
}

module "mysql" {
  source = "../../../../modules/data-stores/mysql"

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
}
