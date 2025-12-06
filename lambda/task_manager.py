import os
import json
import uuid
import time
import logging

import boto3
from botocore.exceptions import ClientError

from utils.response import json_response

# Logging
log = logging.getLogger()
log.setLevel(logging.INFO)

# DynamoDB table
dynamo = boto3.resource("dynamodb")
table = dynamo.Table(os.environ["TABLE_NAME"])

# Helper: parse JSON body safely
def _json(event):
    try:
        return json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return {}

# Helper: extract task ID from path
def _get_task_id(event):
    """Extract task ID from path like /tasks/{id}"""
    path = event.get("path", "")
    parts = path.rstrip("/").split("/")
    # Path should be /tasks/{id}
    if len(parts) >= 3 and parts[-2] == "tasks":
        return parts[-1]
    return None

# Main Lambda handler
def handler(event, context):
    method = event.get("httpMethod")
    path = event.get("path", "")
    
    log.info(f"Request: {method} {path}")

    # GET /tasks - List all tasks
    if method == "GET" and path.endswith("/tasks"):
        return list_tasks(event)
    
    # GET /tasks/{id} - Get single task
    if method == "GET" and "/tasks/" in path:
        task_id = _get_task_id(event)
        if not task_id:
            return json_response(400, {"message": "Invalid task ID"})
        return get_task(task_id)

    # POST /tasks - Create new task
    if method == "POST" and path.endswith("/tasks"):
        return create_task(event)
    
    # PUT /tasks/{id} - Update existing task
    if method == "PUT" and "/tasks/" in path:
        task_id = _get_task_id(event)
        if not task_id:
            return json_response(400, {"message": "Invalid task ID"})
        return update_task(task_id, event)
    
    # DELETE /tasks/{id} - Delete task
    if method == "DELETE" and "/tasks/" in path:
        task_id = _get_task_id(event)
        if not task_id:
            return json_response(400, {"message": "Invalid task ID"})
        return delete_task(task_id)

    # Unsupported method or path
    return json_response(404, {"message": "Not Found"})


def list_tasks(event):
    """GET /tasks - List all tasks with pagination"""
    params = event.get("queryStringParameters") or {}
    limit = min(int(params.get("limit", "25")), 100)
    start_key = params.get("next")

    scan_args = {"Limit": limit}
    if start_key:
        try:
            scan_args["ExclusiveStartKey"] = json.loads(start_key)
        except:
            return json_response(400, {"message": "Invalid 'next' token"})

    try:
        resp = table.scan(**scan_args)
        log.info(f"Scanned {len(resp.get('Items', []))} tasks")
    except Exception as e:
        log.exception("DynamoDB scan failed")
        return json_response(500, {"message": "Failed to fetch tasks"})

    return json_response(200, {
        "items": resp.get("Items", []),
        "count": len(resp.get("Items", [])),
        "next": json.dumps(resp.get("LastEvaluatedKey")) if resp.get("LastEvaluatedKey") else None
    })


def get_task(task_id):
    """GET /tasks/{id} - Get a single task"""
    try:
        resp = table.get_item(Key={"id": task_id})
        
        if "Item" not in resp:
            return json_response(404, {"message": "Task not found"})
        
        log.info(f"Retrieved task: {task_id}")
        return json_response(200, resp["Item"])
        
    except Exception as e:
        log.exception(f"Failed to get task {task_id}")
        return json_response(500, {"message": "Failed to retrieve task"})


def create_task(event):
    """POST /tasks - Create a new task"""
    body = _json(event)
    
    # Validate required fields
    if "task" not in body:
        return json_response(400, {"message": "Missing required field: task"})
    
    if not body["task"].strip():
        return json_response(400, {"message": "Task description cannot be empty"})

    task_id = str(uuid.uuid4())
    now = int(time.time())

    item = {
        "id": task_id,
        "task": body["task"].strip(),
        "status": body.get("status", "new"),
        "priority": body.get("priority", "medium"),
        "created_at": now,
        "updated_at": now
    }

    try:
        table.put_item(
            Item=item,
            ConditionExpression="attribute_not_exists(id)"
        )
        log.info(f"Created task: {task_id}")
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return json_response(409, {"message": "Task ID already exists"})
        log.exception("DynamoDB put_item failed")
        return json_response(500, {"message": "Failed to create task"})

    return json_response(201, {"id": task_id, "task": item})


def update_task(task_id, event):
    """PUT /tasks/{id} - Update an existing task"""
    body = _json(event)
    
    # Check if task exists first
    try:
        existing = table.get_item(Key={"id": task_id})
        if "Item" not in existing:
            return json_response(404, {"message": "Task not found"})
    except Exception as e:
        log.exception(f"Failed to check task existence: {task_id}")
        return json_response(500, {"message": "Failed to update task"})
    
    # Build update expression dynamically
    update_expr = ["#updated_at = :updated_at"]
    expr_attr_names = {"#updated_at": "updated_at"}
    expr_attr_values = {":updated_at": int(time.time())}
    
    # Add task description if provided
    if "task" in body and body["task"].strip():
        update_expr.append("#task = :task")
        expr_attr_names["#task"] = "task"
        expr_attr_values[":task"] = body["task"].strip()
    
    # Add status if provided
    if "status" in body:
        valid_statuses = ["new", "in_progress", "completed", "cancelled"]
        if body["status"] not in valid_statuses:
            return json_response(400, {
                "message": f"Invalid status. Must be one of: {', '.join(valid_statuses)}"
            })
        update_expr.append("#status = :status")
        expr_attr_names["#status"] = "status"
        expr_attr_values[":status"] = body["status"]
    
    # Add priority if provided
    if "priority" in body:
        valid_priorities = ["low", "medium", "high", "urgent"]
        if body["priority"] not in valid_priorities:
            return json_response(400, {
                "message": f"Invalid priority. Must be one of: {', '.join(valid_priorities)}"
            })
        update_expr.append("#priority = :priority")
        expr_attr_names["#priority"] = "priority"
        expr_attr_values[":priority"] = body["priority"]
    
    # No updates provided besides timestamp
    if len(update_expr) == 1:
        return json_response(400, {"message": "No fields to update"})
    
    try:
        resp = table.update_item(
            Key={"id": task_id},
            UpdateExpression="SET " + ", ".join(update_expr),
            ExpressionAttributeNames=expr_attr_names,
            ExpressionAttributeValues=expr_attr_values,
            ReturnValues="ALL_NEW"
        )
        
        log.info(f"Updated task: {task_id}")
        return json_response(200, {
            "message": "Task updated successfully",
            "task": resp["Attributes"]
        })
        
    except Exception as e:
        log.exception(f"Failed to update task {task_id}")
        return json_response(500, {"message": "Failed to update task"})


def delete_task(task_id):
    """DELETE /tasks/{id} - Delete a task"""
    # Check if task exists first
    try:
        existing = table.get_item(Key={"id": task_id})
        if "Item" not in existing:
            return json_response(404, {"message": "Task not found"})
    except Exception as e:
        log.exception(f"Failed to check task existence: {task_id}")
        return json_response(500, {"message": "Failed to delete task"})
    
    # Delete the task
    try:
        table.delete_item(Key={"id": task_id})
        log.info(f"Deleted task: {task_id}")
        return json_response(200, {"message": "Task deleted successfully", "id": task_id})
        
    except Exception as e:
        log.exception(f"Failed to delete task {task_id}")
        return json_response(500, {"message": "Failed to delete task"})

