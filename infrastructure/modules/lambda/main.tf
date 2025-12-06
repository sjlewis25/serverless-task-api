resource "aws_lambda_function" "task" {
  function_name    = "task-manager"
  handler          = "task_manager.handler"
  runtime          = "python3.11"
  role             = var.role_arn
  filename         = "${path.module}/task_manager.zip"
  source_code_hash = filebase64sha256("${path.module}/task_manager.zip")
  
  environment {
    variables = {
      TABLE_NAME = var.table_name
    }
  }
}