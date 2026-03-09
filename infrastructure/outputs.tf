output "lambda_function_name" {
  value = module.lambda_task_manager.lambda_function_name
}

output "lambda_function_arn" {
  value = module.lambda_task_manager.lambda_function_arn
}

output "invoke_url" {
  value = "${aws_api_gateway_stage.main.invoke_url}/tasks"
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID for client configuration"
  value       = aws_cognito_user_pool.tasks.id
}

output "cognito_client_id" {
  description = "Cognito App Client ID for client configuration"
  value       = aws_cognito_user_pool_client.tasks.id
}

output "alarms_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarm notifications"
  value       = aws_sns_topic.alarms.arn
}
