import json
import os

ALLOWED_ORIGIN = os.environ.get("CORS_ORIGIN", "*")

DEFAULT_HEADERS = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
  "Access-Control-Allow-Headers": "Content-Type,Authorization",
  "Access-Control-Allow-Methods": "OPTIONS,GET,POST,PUT,DELETE"
}

def json_response(status, body=None, headers=None):
  h = dict(DEFAULT_HEADERS)
  if headers:
    h.update(headers)
  return {
    "statusCode": int(status),
    "headers": h,
    "body": json.dumps(body if body is not None else {}, default=str)
  }
