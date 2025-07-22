output "lambda_function_name" {
  value = module.lambda_task_manager.lambda_function_name
}

output "lambda_function_arn" {
  value = module.lambda_task_manager.lambda_function_arn
}

output "invoke_url" {
  value = "https://${aws_api_gateway_rest_api.task_api.id}.execute-api.us-east-1.amazonaws.com/dev/tasks"
}