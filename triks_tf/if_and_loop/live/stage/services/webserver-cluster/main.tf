provider "aws" {
  region = "us-east-2"
}

module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"

  cluster_name           = var.cluster_name #"webservers-stage"
  db_remote_state_bucket = var.db_remote_state_bucket #"us-east-2-ivandock-el"
  db_remote_state_key    = var.db_remote_state_key #"stage/data-stores/mysql/terraform.tfstate"

  instance_type        = "t2.micro"
  min_size             = 2
  max_size             = 2
  enable_autoscaling   = false
  enable_new_user_data = true
}
