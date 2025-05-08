import boto3
import json
import uuid

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('Tasks')

def lambda_handler(event, context):
    method = event["httpMethod"]

    if method == "GET":
        try:
            response = table.scan()
            return {
                "statusCode": 200,
                "body": json.dumps(response.get("Items", []))
            }
        except Exception as e:
            return {
                "statusCode": 500,
                "body": json.dumps({"error": str(e)})
            }

    elif method == "POST":
        try:
            body = json.loads(event["body"])
            task_id = str(uuid.uuid4())
            item = {
                "id": task_id,
                "title": body.get("title", "Untitled"),
                "completed": False
            }
            table.put_item(Item=item)
            return {
                "statusCode": 201,
                "body": json.dumps(item)
            }
        except Exception as e:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": str(e)})
            }

    else:
        return {
            "statusCode": 405,
            "body": json.dumps({"message": "Method Not Allowed"})
        }
