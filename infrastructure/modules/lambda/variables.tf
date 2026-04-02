variable "role_arn" {
  description = "IAM role ARN for Lambda execution"
  type        = string
}

variable "table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "function_name" {
  description = "Lambda function name"
  type        = string
  default     = "task-manager"
}

variable "reserved_concurrency" {
  description = "Reserved concurrent executions (-1 = unreserved)"
  type        = number
  default     = 50
}

variable "cors_origin" {
  description = "Allowed CORS origin passed to Lambda as CORS_ORIGIN env var"
  type        = string
  default     = "*"
}
