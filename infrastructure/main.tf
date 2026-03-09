data "aws_region" "current" {}

# ========================================
# Cognito
# ========================================

resource "aws_cognito_user_pool" "tasks" {
  name = "${var.project}-${var.environment}-users"

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
  }

  auto_verified_attributes = ["email"]

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }
}

resource "aws_cognito_user_pool_client" "tasks" {
  name         = "${var.project}-${var.environment}-client"
  user_pool_id = aws_cognito_user_pool.tasks.id

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]
}

# ========================================
# IAM
# ========================================

resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.project}-${var.environment}-lambda-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_policy" "lambda_dynamo_policy" {
  name        = "${var.project}-${var.environment}-lambda-dynamo"
  description = "Allow Lambda to access the tasks DynamoDB table and its indexes"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
      ]
      Resource = [
        aws_dynamodb_table.tasks.arn,
        "${aws_dynamodb_table.tasks.arn}/index/*",
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamo_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_dynamo_policy.arn
}

# API Gateway CloudWatch logging (account-level — only needed once per account)
resource "aws_iam_role" "api_gateway_cloudwatch" {
  name = "${var.project}-${var.environment}-apigw-logs"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch" {
  role       = aws_iam_role.api_gateway_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.api_gateway_cloudwatch.arn
}

# ========================================
# DynamoDB
# ========================================

resource "aws_dynamodb_table" "tasks" {
  name         = "${var.project}-${var.environment}-tasks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "entity_type"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "N"
  }

  global_secondary_index {
    name            = "entity_type-created_at-index"
    hash_key        = "entity_type"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }
}

# ========================================
# Lambda
# ========================================

module "lambda_task_manager" {
  source               = "./modules/lambda"
  role_arn             = aws_iam_role.lambda_exec_role.arn
  table_name           = aws_dynamodb_table.tasks.name
  function_name        = "${var.project}-${var.environment}-task-manager"
  reserved_concurrency = 50
}

# ========================================
# API Gateway
# ========================================

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project}-${var.environment}"
  retention_in_days = 30
}

resource "aws_api_gateway_rest_api" "task_api" {
  name        = "${var.project}-${var.environment}-api"
  description = "Serverless Task Management API"
}

resource "aws_api_gateway_authorizer" "cognito" {
  name          = "cognito-authorizer"
  type          = "COGNITO_USER_POOLS"
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  provider_arns = [aws_cognito_user_pool.tasks.arn]
}

resource "aws_api_gateway_resource" "tasks" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  parent_id   = aws_api_gateway_rest_api.task_api.root_resource_id
  path_part   = "tasks"
}

# ========================================
# CORS OPTIONS /tasks
# ========================================

resource "aws_api_gateway_method" "options" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.tasks.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options" {
  rest_api_id       = aws_api_gateway_rest_api.task_api.id
  resource_id       = aws_api_gateway_resource.tasks.id
  http_method       = "OPTIONS"
  type              = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

resource "aws_api_gateway_method_response" "options_response" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.tasks.id
  http_method = "OPTIONS"
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  response_models = { "application/json" = "Empty" }
  depends_on      = [aws_api_gateway_method.options]
}

resource "aws_api_gateway_integration_response" "options_response" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.tasks.id
  http_method = "OPTIONS"
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,POST,PUT,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${var.cors_origin}'"
  }
  depends_on = [aws_api_gateway_method_response.options_response]
}

# ========================================
# GET /tasks
# ========================================

resource "aws_api_gateway_method" "get_tasks" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.tasks.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "lambda_integration_get" {
  rest_api_id             = aws_api_gateway_rest_api.task_api.id
  resource_id             = aws_api_gateway_resource.tasks.id
  http_method             = aws_api_gateway_method.get_tasks.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${module.lambda_task_manager.lambda_function_arn}/invocations"
}

# ========================================
# POST /tasks
# ========================================

resource "aws_api_gateway_method" "post_tasks" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.tasks.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "lambda_integration_post" {
  rest_api_id             = aws_api_gateway_rest_api.task_api.id
  resource_id             = aws_api_gateway_resource.tasks.id
  http_method             = aws_api_gateway_method.post_tasks.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${module.lambda_task_manager.lambda_function_arn}/invocations"
}

# ========================================
# /tasks/{id}
# ========================================

resource "aws_api_gateway_resource" "task_id" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  parent_id   = aws_api_gateway_resource.tasks.id
  path_part   = "{id}"
}

# ========================================
# CORS OPTIONS /tasks/{id}
# ========================================

resource "aws_api_gateway_method" "task_id_options" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.task_id.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "task_id_options" {
  rest_api_id       = aws_api_gateway_rest_api.task_api.id
  resource_id       = aws_api_gateway_resource.task_id.id
  http_method       = "OPTIONS"
  type              = "MOCK"
  request_templates = { "application/json" = "{\"statusCode\": 200}" }
}

resource "aws_api_gateway_method_response" "task_id_options_response" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.task_id.id
  http_method = "OPTIONS"
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  response_models = { "application/json" = "Empty" }
  depends_on      = [aws_api_gateway_method.task_id_options]
}

resource "aws_api_gateway_integration_response" "task_id_options_response" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.task_id.id
  http_method = "OPTIONS"
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,GET,PUT,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${var.cors_origin}'"
  }
  depends_on = [aws_api_gateway_method_response.task_id_options_response]
}

# ========================================
# GET /tasks/{id}
# ========================================

resource "aws_api_gateway_method" "get_task" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.task_id.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "lambda_integration_get_task" {
  rest_api_id             = aws_api_gateway_rest_api.task_api.id
  resource_id             = aws_api_gateway_resource.task_id.id
  http_method             = aws_api_gateway_method.get_task.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${module.lambda_task_manager.lambda_function_arn}/invocations"
}

# ========================================
# PUT /tasks/{id}
# ========================================

resource "aws_api_gateway_method" "put_task" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.task_id.id
  http_method   = "PUT"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "lambda_integration_put" {
  rest_api_id             = aws_api_gateway_rest_api.task_api.id
  resource_id             = aws_api_gateway_resource.task_id.id
  http_method             = aws_api_gateway_method.put_task.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${module.lambda_task_manager.lambda_function_arn}/invocations"
}

# ========================================
# DELETE /tasks/{id}
# ========================================

resource "aws_api_gateway_method" "delete_task" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.task_id.id
  http_method   = "DELETE"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "lambda_integration_delete" {
  rest_api_id             = aws_api_gateway_rest_api.task_api.id
  resource_id             = aws_api_gateway_resource.task_id.id
  http_method             = aws_api_gateway_method.delete_task.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${module.lambda_task_manager.lambda_function_arn}/invocations"
}

# ========================================
# Lambda permission
# ========================================

resource "aws_lambda_permission" "api_gateway_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_task_manager.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.task_api.execution_arn}/${var.environment}/*"
}

# ========================================
# Deployment and stage
# ========================================

resource "aws_api_gateway_deployment" "task_api_deploy" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.tasks.id,
      aws_api_gateway_resource.task_id.id,
      aws_api_gateway_method.get_tasks.id,
      aws_api_gateway_method.post_tasks.id,
      aws_api_gateway_method.get_task.id,
      aws_api_gateway_method.put_task.id,
      aws_api_gateway_method.delete_task.id,
      aws_api_gateway_authorizer.cognito.id,
    ]))
  }

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
    aws_api_gateway_integration_response.task_id_options_response,
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "main" {
  deployment_id        = aws_api_gateway_deployment.task_api_deploy.id
  rest_api_id          = aws_api_gateway_rest_api.task_api.id
  stage_name           = var.environment
  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      errorMessage   = "$context.error.message"
    })
  }

  depends_on = [aws_api_gateway_account.main]
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  stage_name  = aws_api_gateway_stage.main.stage_name
  method_path = "*/*"

  settings {
    throttling_burst_limit = 200
    throttling_rate_limit  = 100
    metrics_enabled        = true
    logging_level          = "ERROR"
  }
}
