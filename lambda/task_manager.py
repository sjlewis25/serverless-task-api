import base64
import decimal
import json
import os
import time
import uuid

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError
from aws_lambda_powertools import Logger, Tracer

from utils.response import json_response

logger = Logger()
tracer = Tracer()

# DynamoDB
dynamo = boto3.resource("dynamodb")
table  = dynamo.Table(os.environ["TABLE_NAME"])

def _json_default(obj):
    if isinstance(obj, decimal.Decimal):
        return int(obj) if obj == int(obj) else float(obj)
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")


GSI_NAME         = "user_id-created_at-index"
TASK_MAX_LEN     = 1000
VALID_STATUSES   = {"new", "in_progress", "completed", "cancelled"}
VALID_PRIORITIES = {"low", "medium", "high", "urgent"}


def _json(event):
    try:
        return json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return {}


def _task_id_from_path(event):
    path_params = event.get("pathParameters") or {}
    return path_params.get("id")


def _user_id(event):
    """Extract the Cognito sub claim — unique, stable identifier per user."""
    return event["requestContext"]["authorizer"]["claims"]["sub"]


@logger.inject_lambda_context
@tracer.capture_lambda_handler
def handler(event, context):
    method  = event.get("httpMethod", "")
    path    = event.get("path", "")
    user_id = _user_id(event)
    logger.info(json.dumps({"request": f"{method} {path}", "user": user_id}))

    on_collection = path.rstrip("/").endswith("/tasks") or path == "/tasks"
    on_item       = "/tasks/" in path

    if on_collection:
        if method == "GET":
            return list_tasks(event, user_id)
        if method == "POST":
            return create_task(event, user_id)
        return json_response(405, {"message": "Method Not Allowed"})

    if on_item:
        task_id = _task_id_from_path(event)
        if not task_id:
            return json_response(400, {"message": "Invalid task ID"})
        if method == "GET":
            return get_task(task_id, user_id)
        if method == "PUT":
            return update_task(task_id, event, user_id)
        if method == "DELETE":
            return delete_task(task_id, user_id)
        return json_response(405, {"message": "Method Not Allowed"})

    return json_response(404, {"message": "Not Found"})


def list_tasks(event, user_id):
    params = event.get("queryStringParameters") or {}
    try:
        limit = min(int(params.get("limit", "25")), 100)
    except ValueError:
        return json_response(400, {"message": "Invalid 'limit' parameter — must be an integer"})
    token  = params.get("next")

    query_args = {
        "IndexName":              GSI_NAME,
        "KeyConditionExpression": Key("user_id").eq(user_id),
        "Limit":                  limit,
        "ScanIndexForward":       False,  # newest first
    }

    if token:
        try:
            query_args["ExclusiveStartKey"] = json.loads(
                base64.b64decode(token.encode()).decode()
            )
        except Exception:
            return json_response(400, {"message": "Invalid 'next' token"})

    try:
        resp = table.query(**query_args)
        logger.info(json.dumps({"action": "list_tasks", "count": len(resp.get("Items", []))}))
    except Exception:
        logger.exception("DynamoDB query failed")
        return json_response(500, {"message": "Failed to fetch tasks"})

    next_token = None
    if resp.get("LastEvaluatedKey"):
        next_token = base64.b64encode(
            json.dumps(resp["LastEvaluatedKey"], default=_json_default).encode()
        ).decode()

    return json_response(200, {
        "items": resp.get("Items", []),
        "count": len(resp.get("Items", [])),
        "next":  next_token,
    })


def get_task(task_id, user_id):
    try:
        resp = table.get_item(Key={"id": task_id})
        if "Item" not in resp or resp["Item"].get("user_id") != user_id:
            return json_response(404, {"message": "Task not found"})
        logger.info(json.dumps({"action": "get_task", "id": task_id}))
        return json_response(200, resp["Item"])
    except Exception:
        logger.exception("Failed to get task %s", task_id)
        return json_response(500, {"message": "Failed to retrieve task"})


def create_task(event, user_id):
    body = _json(event)

    if "task" not in body:
        return json_response(400, {"message": "Missing required field: task"})

    if not isinstance(body["task"], str):
        return json_response(400, {"message": "Task description must be a string"})
    task_text = body["task"].strip()
    if not task_text:
        return json_response(400, {"message": "Task description cannot be empty"})
    if len(task_text) > TASK_MAX_LEN:
        return json_response(400, {"message": f"Task description cannot exceed {TASK_MAX_LEN} characters"})

    status   = body.get("status", "new")
    priority = body.get("priority", "medium")

    if status not in VALID_STATUSES:
        return json_response(400, {"message": f"Invalid status. Must be one of: {', '.join(sorted(VALID_STATUSES))}"})
    if priority not in VALID_PRIORITIES:
        return json_response(400, {"message": f"Invalid priority. Must be one of: {', '.join(sorted(VALID_PRIORITIES))}"})

    task_id = str(uuid.uuid4())
    now     = int(time.time())

    item = {
        "id":         task_id,
        "user_id":    user_id,
        "task":       task_text,
        "status":      status,
        "priority":    priority,
        "created_at":  now,
        "updated_at":  now,
    }

    try:
        table.put_item(Item=item, ConditionExpression="attribute_not_exists(id)")
        logger.info(json.dumps({"action": "create_task", "id": task_id}))
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return json_response(409, {"message": "Task ID collision, please retry"})
        logger.exception("DynamoDB put_item failed")
        return json_response(500, {"message": "Failed to create task"})

    return json_response(201, {"id": task_id, "task": item})


def update_task(task_id, event, user_id):
    body = _json(event)

    update_expr      = ["#updated_at = :updated_at"]
    expr_attr_names  = {"#updated_at": "updated_at"}
    expr_attr_values = {":updated_at": int(time.time()), ":owner": user_id}

    if "task" in body:
        if not isinstance(body["task"], str):
            return json_response(400, {"message": "Task description must be a string"})
        task_text = body["task"].strip()
        if not task_text:
            return json_response(400, {"message": "Task description cannot be empty"})
        if len(task_text) > TASK_MAX_LEN:
            return json_response(400, {"message": f"Task description cannot exceed {TASK_MAX_LEN} characters"})
        update_expr.append("#task = :task")
        expr_attr_names["#task"]  = "task"
        expr_attr_values[":task"] = task_text

    if "status" in body:
        if body["status"] not in VALID_STATUSES:
            return json_response(400, {"message": f"Invalid status. Must be one of: {', '.join(sorted(VALID_STATUSES))}"})
        update_expr.append("#status = :status")
        expr_attr_names["#status"]  = "status"
        expr_attr_values[":status"] = body["status"]

    if "priority" in body:
        if body["priority"] not in VALID_PRIORITIES:
            return json_response(400, {"message": f"Invalid priority. Must be one of: {', '.join(sorted(VALID_PRIORITIES))}"})
        update_expr.append("#priority = :priority")
        expr_attr_names["#priority"]  = "priority"
        expr_attr_values[":priority"] = body["priority"]

    if len(update_expr) == 1:
        return json_response(400, {"message": "No fields to update"})

    try:
        resp = table.update_item(
            Key={"id": task_id},
            UpdateExpression="SET " + ", ".join(update_expr),
            ExpressionAttributeNames=expr_attr_names,
            ExpressionAttributeValues=expr_attr_values,
            ConditionExpression="attribute_exists(id) AND user_id = :owner",
            ReturnValues="ALL_NEW",
        )
        logger.info(json.dumps({"action": "update_task", "id": task_id}))
        return json_response(200, {"message": "Task updated", "task": resp["Attributes"]})
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return json_response(404, {"message": "Task not found"})
        logger.exception("Failed to update task %s", task_id)
        return json_response(500, {"message": "Failed to update task"})


def delete_task(task_id, user_id):
    try:
        table.delete_item(
            Key={"id": task_id},
            ConditionExpression="attribute_exists(id) AND user_id = :owner",
            ExpressionAttributeValues={":owner": user_id},
        )
        logger.info(json.dumps({"action": "delete_task", "id": task_id}))
        return json_response(204, None)
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return json_response(404, {"message": "Task not found"})
        logger.exception("Failed to delete task %s", task_id)
        return json_response(500, {"message": "Failed to delete task"})
