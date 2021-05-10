provider "aws" {
  region = "us-east-2"
}

module "hello_world_app" {
  source = "../../../modules/services/hello-world-app"

  server_text = var.server_text

  environment = var.environment

  # Pass all the outputs from the mysql module straight through
  mysql_config = var.mysql_config

  instance_type      = "t2.micro"
  min_size           = 2
  max_size           = 2
  enable_autoscaling = false
}

#module "mysql" {
#  source = "../../../modules/data-stores/mysql"

#  db_name     = var.db_name
#  db_username = var.db_username
#  db_password = var.db_password
#}
