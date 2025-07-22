output "lambda_function_arn" {
  value = aws_lambda_function.task.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.task.function_name
}
