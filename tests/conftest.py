import json
import os
import sys
import time
import uuid

import boto3
import pytest
from moto import mock_aws

# Add lambda/ to path so tests can import task_manager
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lambda"))

# Must be set before task_manager is imported (module reads these at import time)
os.environ.setdefault("TABLE_NAME", "test-tasks")
os.environ.setdefault("CORS_ORIGIN", "*")
os.environ.setdefault("POWERTOOLS_TRACE_DISABLED", "true")
os.environ.setdefault("POWERTOOLS_SERVICE_NAME", "test")
os.environ.setdefault("AWS_DEFAULT_REGION", "us-east-1")
os.environ.setdefault("AWS_ACCESS_KEY_ID", "testing")
os.environ.setdefault("AWS_SECRET_ACCESS_KEY", "testing")
os.environ.setdefault("AWS_SECURITY_TOKEN", "testing")
os.environ.setdefault("AWS_SESSION_TOKEN", "testing")


@pytest.fixture
def table():
    """Spin up a mocked DynamoDB table and patch it into the task_manager module."""
    with mock_aws():
        dynamo = boto3.resource("dynamodb", region_name="us-east-1")
        tbl = dynamo.create_table(
            TableName="test-tasks",
            KeySchema=[{"AttributeName": "id", "KeyType": "HASH"}],
            AttributeDefinitions=[
                {"AttributeName": "id", "AttributeType": "S"},
                {"AttributeName": "user_id", "AttributeType": "S"},
                {"AttributeName": "created_at", "AttributeType": "N"},
            ],
            GlobalSecondaryIndexes=[{
                "IndexName": "user_id-created_at-index",
                "KeySchema": [
                    {"AttributeName": "user_id", "KeyType": "HASH"},
                    {"AttributeName": "created_at", "KeyType": "RANGE"},
                ],
                "Projection": {"ProjectionType": "ALL"},
            }],
            BillingMode="PAY_PER_REQUEST",
        )
        import task_manager
        task_manager.table = tbl
        yield tbl


class FakeLambdaContext:
    function_name = "test-function"
    memory_limit_in_mb = 128
    invoked_function_arn = "arn:aws:lambda:us-east-1:123456789012:function:test-function"
    aws_request_id = "test-request-id"


CONTEXT = FakeLambdaContext()


def make_event(method, path, path_params=None, body=None, query_params=None, user_id="user-aaa"):
    """Build a minimal API Gateway proxy event."""
    return {
        "httpMethod": method,
        "path": path,
        "pathParameters": path_params,
        "queryStringParameters": query_params,
        "body": json.dumps(body) if body is not None else None,
        "requestContext": {
            "authorizer": {
                "claims": {"sub": user_id}
            }
        },
    }


def seed_task(table, user_id="user-aaa", task_text="Buy milk", status="new", priority="medium", offset=0):
    """Insert a task directly into the table; returns the item dict."""
    now = int(time.time()) + offset
    item = {
        "id": str(uuid.uuid4()),
        "user_id": user_id,
        "task": task_text,
        "status": status,
        "priority": priority,
        "created_at": now,
        "updated_at": now,
    }
    table.put_item(Item=item)
    return item
