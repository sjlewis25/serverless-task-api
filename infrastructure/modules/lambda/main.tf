resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 30
}

resource "aws_lambda_function" "task" {
  function_name    = var.function_name
  handler          = "task_manager.handler"
  runtime          = "python3.11"
  role             = var.role_arn
  filename         = "${path.module}/task_manager.zip"
  source_code_hash = filebase64sha256("${path.module}/task_manager.zip")

  reserved_concurrent_executions = var.reserved_concurrency

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      TABLE_NAME  = var.table_name
      CORS_ORIGIN = var.cors_origin
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}
