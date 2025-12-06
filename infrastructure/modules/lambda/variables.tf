variable "role_arn" {
  description = "IAM role ARN for Lambda execution"
  type        = string
}

variable "table_name" {
  description = "DynamoDB table name"
  type        = string
}