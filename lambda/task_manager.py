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

# Main Lambda handler
def handler(event, context):
    method = event.get("httpMethod")
    path = event.get("path", "")

    # GET /tasks
    if method == "GET" and path.endswith("/tasks"):
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
        except Exception as e:
            log.exception("DynamoDB scan failed")
            return json_response(500, {"message": "Failed to fetch tasks"})

        return json_response(200, {
            "items": resp.get("Items", []),
            "next": json.dumps(resp.get("LastEvaluatedKey")) if resp.get("LastEvaluatedKey") else None
        })

    # POST /tasks
    if method == "POST" and path.endswith("/tasks"):
        body = _json(event)
        if "task" not in body:
            return json_response(400, {"message": "Missing required field: task"})

        task_id = str(uuid.uuid4())
        now = int(time.time())

        item = {
            "id": task_id,
            "task": body["task"],
            "status": body.get("status", "new"),
            "created_at": now,
            "updated_at": now
        }

        try:
            table.put_item(
                Item=item,
                ConditionExpression="attribute_not_exists(id)"
            )
        except ClientError as e:
            if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
                return json_response(409, {"message": "Task ID already exists"})
            log.exception("DynamoDB put_item failed")
            return json_response(500, {"message": "Failed to create task"})

        return json_response(201, {"id": task_id})

    # Unsupported method or path
    return json_response(404, {"message": "Not Found"})

