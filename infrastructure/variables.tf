variable "project" {
  type = string
  default = "serverless-task-api"
}

variable "environment" {
  type = string
  default = "dev"
}

variable "region" {
  type = string
  default = "us-east-1"
}

variable "owner" {
  type = string
  default = "steve"
}

variable "tf_state_bucket" {
  type = string
}

variable "tf_lock_table" {
  type = string
}

variable "table_name" {
  type = string
  default = "tasks"
}
