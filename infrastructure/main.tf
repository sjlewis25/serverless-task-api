resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "lambda_dynamo_policy" {
  name        = "lambda-dynamo-access"
  description = "Allow Lambda to access DynamoDB"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Scan",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem"
      ],
      Effect = "Allow",
      Resource = aws_dynamodb_table.tasks.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamo_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_dynamo_policy.arn
}

resource "aws_dynamodb_table" "tasks" {
  name         = "Tasks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

module "lambda_task_manager" {
  source     = "./modules/lambda"
  role_arn   = aws_iam_role.lambda_exec_role.arn
  table_name = aws_dynamodb_table.tasks.name
}

resource "aws_api_gateway_rest_api" "task_api" {
  name        = "TaskAPI"
  description = "Serverless Task Management API"
}

resource "aws_api_gateway_resource" "tasks" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  parent_id   = aws_api_gateway_rest_api.task_api.root_resource_id
  path_part   = "tasks"
}

# ========================================
# CORS OPTIONS for /tasks
# ========================================

resource "aws_api_gateway_method" "options" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.tasks.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.tasks.id
  http_method = "OPTIONS"
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_response" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.tasks.id
  http_method = "OPTIONS"
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }

  depends_on = [aws_api_gateway_method.options]
}

resource "aws_api_gateway_integration_response" "options_response" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.tasks.id
  http_method = "OPTIONS"
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'",
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,POST,PUT,DELETE'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_method_response.options_response]
}

# ========================================
# GET /tasks - List all tasks
# ========================================

resource "aws_api_gateway_method" "get_tasks" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.tasks.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration_get" {
  rest_api_id             = aws_api_gateway_rest_api.task_api.id
  resource_id             = aws_api_gateway_resource.tasks.id
  http_method             = aws_api_gateway_method.get_tasks.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${module.lambda_task_manager.lambda_function_arn}/invocations"
}

# ========================================
# POST /tasks - Create task
# ========================================

resource "aws_api_gateway_method" "post_tasks" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.tasks.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration_post" {
  rest_api_id             = aws_api_gateway_rest_api.task_api.id
  resource_id             = aws_api_gateway_resource.tasks.id
  http_method             = aws_api_gateway_method.post_tasks.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${module.lambda_task_manager.lambda_function_arn}/invocations"
}

# ========================================
# /tasks/{id} resource
# ========================================

resource "aws_api_gateway_resource" "task_id" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  parent_id   = aws_api_gateway_resource.tasks.id
  path_part   = "{id}"
}

# ========================================
# CORS OPTIONS for /tasks/{id}
# ========================================

resource "aws_api_gateway_method" "task_id_options" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.task_id.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "task_id_options" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.task_id.id
  http_method = "OPTIONS"
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "task_id_options_response" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.task_id.id
  http_method = "OPTIONS"
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }

  depends_on = [aws_api_gateway_method.task_id_options]
}

resource "aws_api_gateway_integration_response" "task_id_options_response" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.task_id.id
  http_method = "OPTIONS"
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'",
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,PUT,DELETE'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [aws_api_gateway_method_response.task_id_options_response]
}

# ========================================
# GET /tasks/{id} - Get single task
# ========================================

resource "aws_api_gateway_method" "get_task" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.task_id.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration_get_task" {
  rest_api_id             = aws_api_gateway_rest_api.task_api.id
  resource_id             = aws_api_gateway_resource.task_id.id
  http_method             = aws_api_gateway_method.get_task.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${module.lambda_task_manager.lambda_function_arn}/invocations"
}

# ========================================
# PUT /tasks/{id} - Update task
# ========================================

resource "aws_api_gateway_method" "put_task" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.task_id.id
  http_method   = "PUT"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration_put" {
  rest_api_id             = aws_api_gateway_rest_api.task_api.id
  resource_id             = aws_api_gateway_resource.task_id.id
  http_method             = aws_api_gateway_method.put_task.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${module.lambda_task_manager.lambda_function_arn}/invocations"
}

# ========================================
# DELETE /tasks/{id} - Delete task
# ========================================

resource "aws_api_gateway_method" "delete_task" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.task_id.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration_delete" {
  rest_api_id             = aws_api_gateway_rest_api.task_api.id
  resource_id             = aws_api_gateway_resource.task_id.id
  http_method             = aws_api_gateway_method.delete_task.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${module.lambda_task_manager.lambda_function_arn}/invocations"
}

# ========================================
# Lambda permissions
# ========================================

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_task_manager.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.task_api.execution_arn}/dev/*"
}

# ========================================
# API Gateway deployment
# ========================================

resource "aws_api_gateway_deployment" "task_api_deploy" {
  depends_on = [
    aws_api_gateway_integration.lambda_integration_get,
    aws_api_gateway_integration.lambda_integration_post,
    aws_api_gateway_integration.options,
    aws_api_gateway_method_response.options_response,
    aws_api_gateway_integration_response.options_response,
    aws_api_gateway_integration.lambda_integration_get_task,
    aws_api_gateway_integration.lambda_integration_put,
    aws_api_gateway_integration.lambda_integration_delete,
    aws_api_gateway_integration.task_id_options,
    aws_api_gateway_method_response.task_id_options_response,
    aws_api_gateway_integration_response.task_id_options_response
  ]

  rest_api_id = aws_api_gateway_rest_api.task_api.id
  stage_name  = "dev"
}
