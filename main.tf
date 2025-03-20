provider "aws" {
  region = "us-east-1"
}

resource "aws_dynamodb_table" "tasks" {
  name         = "TasksTable"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "taskId"
    type = "S"
  }

  hash_key = "taskId"
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_task_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy_attachment" "lambda_dynamodb" {
  name       = "lambda_dynamodb_policy"
  roles      = [aws_iam_role.lambda_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_lambda_function" "task_lambda" {
  function_name    = "taskManagerLambda"
  filename         = "../lambdas/task_manager.zip"
  source_code_hash = filebase64sha256("../lambdas/task_manager.zip")
  role             = aws_iam_role.lambda_role.arn
  handler          = "task_manager.lambda_handler"
  runtime          = "python3.9"
}

resource "aws_api_gateway_rest_api" "task_api" {
  name        = "TaskAPI"
  description = "Serverless Task Management API"
}

resource "aws_api_gateway_resource" "task_resource" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  parent_id   = aws_api_gateway_rest_api.task_api.root_resource_id
  path_part   = "tasks"
}

resource "aws_api_gateway_method" "task_method" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.task_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.task_api.id
  resource_id             = aws_api_gateway_resource.task_resource.id
  http_method             = aws_api_gateway_method.task_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.task_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on  = [aws_api_gateway_integration.lambda_integration]
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  stage_name  = "prod"
}

output "api_endpoint" {
  value = aws_api_gateway_deployment.api_deployment.invoke_url
}
