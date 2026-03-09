resource "aws_sns_topic" "alarms" {
  name = "${var.project}-${var.environment}-alarms"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Lambda error rate > 5% over 2 consecutive minutes
resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  alarm_name        = "${var.project}-${var.environment}-lambda-error-rate"
  alarm_description = "Lambda error rate exceeded 5%"
  treat_missing_data = "notBreaching"

  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 5

  metric_query {
    id          = "error_rate"
    expression  = "errors / MAX([errors, invocations]) * 100"
    label       = "Error Rate (%)"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      namespace   = "AWS/Lambda"
      metric_name = "Errors"
      period      = 60
      stat        = "Sum"
      dimensions  = { FunctionName = module.lambda_task_manager.lambda_function_name }
    }
  }

  metric_query {
    id = "invocations"
    metric {
      namespace   = "AWS/Lambda"
      metric_name = "Invocations"
      period      = 60
      stat        = "Sum"
      dimensions  = { FunctionName = module.lambda_task_manager.lambda_function_name }
    }
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]
}

# Lambda p99 duration approaching 30s timeout
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.project}-${var.environment}-lambda-duration-p99"
  alarm_description   = "Lambda p99 duration is approaching the 30s timeout"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  extended_statistic  = "p99"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  threshold           = 25000 # 25s — 83% of the 30s timeout
  treat_missing_data  = "notBreaching"
  dimensions          = { FunctionName = module.lambda_task_manager.lambda_function_name }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]
}

# Lambda throttles
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${var.project}-${var.environment}-lambda-throttles"
  alarm_description   = "Lambda is being throttled — reserved concurrency may be too low"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  dimensions          = { FunctionName = module.lambda_task_manager.lambda_function_name }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]
}

# API Gateway 5xx errors
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.project}-${var.environment}-api-5xx"
  alarm_description   = "API Gateway 5XX error count is elevated"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"
  dimensions = {
    ApiName = aws_api_gateway_rest_api.task_api.name
    Stage   = aws_api_gateway_stage.main.stage_name
  }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]
}

# DynamoDB throttled requests
resource "aws_cloudwatch_metric_alarm" "dynamo_throttles" {
  alarm_name          = "${var.project}-${var.environment}-dynamo-throttles"
  alarm_description   = "DynamoDB is throttling requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  dimensions          = { TableName = aws_dynamodb_table.tasks.name }

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]
}
