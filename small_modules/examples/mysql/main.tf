terraform {
  required_version = ">= 0.14, < 0.15"
}

provider "aws" {
  region = "us-east-2"

  version = "~> 3.0"
}

module "mysql" {
  source = "../../modules/data-stores/mysql"

  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
}
