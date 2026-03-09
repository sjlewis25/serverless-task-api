variable "project" {
  type    = string
  default = "serverless-task-api"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "owner" {
  type    = string
  default = "steve"
}

variable "tf_state_bucket" {
  type = string
}

variable "tf_lock_table" {
  type = string
}

variable "table_name" {
  type    = string
  default = "tasks"
}

variable "cors_origin" {
  type        = string
  description = "Allowed CORS origin (e.g. https://example.com). Defaults to wildcard."
  default     = "*"
}

variable "alert_email" {
  type        = string
  description = "Email address for CloudWatch alarm notifications. Leave empty to skip subscription."
  default     = ""
}
