![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform)
![AWS](https://img.shields.io/badge/Cloud-AWS-FF9900?logo=amazon-aws)
![Lambda](https://img.shields.io/badge/Compute-Lambda-FF9900?logo=aws-lambda)
![DynamoDB](https://img.shields.io/badge/Database-DynamoDB-4053D6?logo=amazon-dynamodb)
![Python](https://img.shields.io/badge/Runtime-Python_3.11-3776AB?logo=python)

# Serverless Task API

Production-grade serverless REST API built with AWS Lambda, API Gateway, DynamoDB, and Cognito. Deployed on AWS using Terraform for repeatable, infrastructure-as-code deployments. Includes authentication, observability, throttling, automated alerting, and safe deployment tooling.

## Problem Statement

Organizations building web applications need backend APIs to handle data operations, but traditional server-based architectures create significant operational overhead.

Running a dedicated EC2 instance or container cluster for a simple CRUD API costs $15 to $50 per month minimum, even during periods of zero traffic. These servers require patching, monitoring, and capacity planning. For small teams and early-stage applications, this represents wasted spend and engineering time on infrastructure that could be spent on product development.

Additionally, traditional architectures require manual scaling decisions. Underprovisioning leads to downtime during traffic spikes, while overprovisioning wastes money during quiet periods. Teams must choose between reliability and cost efficiency.

This project addresses these challenges by implementing a fully serverless architecture that scales automatically from zero to thousands of concurrent requests, costs nothing at idle, and eliminates all server management. The API handles full CRUD operations for task management while demonstrating production-grade serverless patterns: JWT authentication, efficient database access, distributed tracing, structured logging, and automated operational alerting.

## Architecture

```
Client (with JWT token)
  │
  ▼
API Gateway  ──── Cognito User Pool (JWT validation) ────► 401 if invalid
  │  throttle: 100 req/s, 200 burst
  │  access logs → CloudWatch
  │
  ▼
Lambda (task_manager.py)
  │  X-Ray tracing active
  │  reserved concurrency: 50
  │  structured JSON logs → CloudWatch
  │
  ├── GET    /tasks        → Query GSI (entity_type + created_at), newest first
  ├── POST   /tasks        → Conditional write, return 201
  ├── GET    /tasks/{id}   → GetItem by primary key
  ├── PUT    /tasks/{id}   → Conditional update (404 if not found)
  └── DELETE /tasks/{id}   → Conditional delete (404 if not found), return 204
        │
        ▼
    DynamoDB (Tasks table)
      • Primary key: id (UUID)
      • GSI: entity_type + created_at (for efficient list queries)
      • Point-in-time recovery enabled
        │
        ▼
    CloudWatch Alarms → SNS → Email
      • Lambda error rate > 5%
      • Lambda p99 duration > 25s
      • Lambda throttles > 0
      • API Gateway 5xx > 10
      • DynamoDB throttles > 0
```

## Technology Stack

**Auth**
AWS Cognito User Pool handles user registration, email verification, and JWT issuance. API Gateway validates tokens on every request before invoking Lambda, so unauthorized requests never reach application code.

**Compute**
AWS Lambda runs Python 3.11. Reserved concurrency caps execution at 50 to prevent runaway scaling during traffic spikes. X-Ray active tracing captures request timelines from API Gateway through Lambda to DynamoDB for performance analysis and debugging.

**API Layer**
Amazon API Gateway with Cognito authorizer, per-stage throttling (100 req/s rate, 200 burst), structured access logging to CloudWatch, and CORS support. Deployment uses `create_before_destroy` for zero-downtime redeploys.

**Database**
Amazon DynamoDB with on-demand billing. A Global Secondary Index on `entity_type + created_at` enables efficient list queries returning newest tasks first — no full-table scans. Point-in-time recovery allows restoration to any second within the last 35 days.

**Observability**
Structured JSON logging on every Lambda log line. Five CloudWatch metric alarms covering error rate, latency, throttling, and DynamoDB health. SNS topic delivers alarm notifications to a configurable email address. Lambda and API Gateway log groups have 30-day retention.

**Infrastructure**
Terraform with modular Lambda configuration, remote S3 state with DynamoDB locking, and environment-prefixed resource names. Deployment script generates a plan for review before applying.

## Key Features

**JWT Authentication**
All endpoints require a valid Cognito-issued JWT in the `Authorization` header. Users register and authenticate through Cognito. API Gateway rejects any request without a valid token before Lambda is invoked.

**Efficient List Queries**
Tasks are listed using a DynamoDB Query on a GSI (`entity_type + created_at`) rather than a full-table Scan. Cost and latency scale with the page size, not the total number of tasks. Results are returned newest-first.

**Opaque Pagination Tokens**
The `next` cursor is base64-encoded before returning to clients. Internal DynamoDB key structure is not exposed.

**Atomic Conditional Writes**
Update and delete operations use a single DynamoDB call with `ConditionExpression="attribute_exists(id)"`. Existence is checked atomically — no separate read round trip. Returns 404 if the item does not exist.

**Input Validation**
`task` description is required, must be non-empty, and cannot exceed 1000 characters. `status` and `priority` are validated against allowed values on both create and update. Validation errors return 400 with a descriptive message.

**Graduated HTTP Status Codes**
- 201 on create
- 204 (no body) on delete
- 404 when item does not exist
- 405 when method is not allowed on a valid path
- 409 on ID collision

**Automated Alerting**
Five CloudWatch alarms fire via SNS email when thresholds are breached and recover automatically when conditions clear.

**Cost Efficient**
The entire stack operates within AWS Free Tier for development and light production use. At medium production volume of 1 million requests per month, total cost is approximately $4.50 — compared to $25+ for equivalent EC2-based infrastructure.

## Deployment

**Prerequisites**
- AWS account with administrative access
- AWS CLI configured with credentials
- Terraform 1.6 or higher
- Python 3.11
- Bash shell (Linux, macOS, or Git Bash on Windows)

**Setup**

Clone the repository:
```
git clone https://github.com/sjlewis25/serverless-task-api.git
cd serverless-task-api
```

Create `infrastructure/terraform.tfvars`:
```hcl
tf_state_bucket = "your-terraform-state-bucket"
tf_lock_table   = "your-terraform-lock-table"
environment     = "dev"
alert_email     = "you@example.com"       # optional — leave empty to skip alarm emails
cors_origin     = "https://yourapp.com"   # optional — defaults to *
```

**Deploy**

Package Lambda and deploy all infrastructure:
```
cd scripts
./deploy.sh
```

The script packages the Lambda zip, runs `terraform plan`, shows the changes, and prompts for confirmation before applying.

Confirm SNS alarm subscription by clicking the link in the email from AWS.

**Outputs after deployment:**
```
invoke_url           = "https://abc123.execute-api.us-east-1.amazonaws.com/dev/tasks"
cognito_user_pool_id = "us-east-1_XXXXXXXXX"
cognito_client_id    = "xxxxxxxxxxxxxxxxxxxxxxxxxx"
alarms_topic_arn     = "arn:aws:sns:us-east-1:123456789:serverless-task-api-dev-alarms"
```

**Manual deployment:**
```
cd lambda
zip -r ../infrastructure/modules/lambda/task_manager.zip .
cd ../infrastructure
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

**Authenticate and test:**

Register a user:
```
aws cognito-idp sign-up \
  --client-id <cognito_client_id> \
  --username you@example.com \
  --password "YourPassword1!"
```

Confirm the user (check email for code):
```
aws cognito-idp confirm-sign-up \
  --client-id <cognito_client_id> \
  --username you@example.com \
  --confirmation-code 123456
```

Get a JWT token:
```
TOKEN=$(aws cognito-idp initiate-auth \
  --client-id <cognito_client_id> \
  --auth-flow USER_SRP_AUTH \
  --auth-parameters USERNAME=you@example.com,PASSWORD="YourPassword1!" \
  --query 'AuthenticationResult.IdToken' \
  --output text)
```

Create a task:
```
curl -X POST $API_URL \
  -H "Authorization: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"task": "Test deployment", "priority": "high"}'
```

## API Reference

All requests require `Authorization: <JWT>` header. All responses are `application/json`.

**Create Task**
```
POST /tasks
Authorization: <JWT>
Content-Type: application/json

{
  "task": "Write documentation",   # required, 1–1000 chars
  "status": "new",                 # optional, default: new
  "priority": "medium"             # optional, default: medium
}

201 Created
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "task": { ...full task object... }
}

Valid status values:   new, in_progress, completed, cancelled
Valid priority values: low, medium, high, urgent
```

**List Tasks**
```
GET /tasks?limit=25&next=<token>
Authorization: <JWT>

200 OK
{
  "items": [...],
  "count": 25,
  "next": "<base64_token_or_null>"   # pass as ?next= to get next page
}

Results are sorted newest first. Max limit: 100.
```

**Get Task**
```
GET /tasks/{id}
Authorization: <JWT>

200 OK  → task object
404     → {"message": "Task not found"}
```

**Update Task**
```
PUT /tasks/{id}
Authorization: <JWT>
Content-Type: application/json

{
  "task": "Updated description",   # optional
  "status": "in_progress",         # optional
  "priority": "urgent"             # optional
}

200 OK  → {"message": "Task updated", "task": {...}}
400     → if no valid fields provided, or validation failure
404     → {"message": "Task not found"}
```

**Delete Task**
```
DELETE /tasks/{id}
Authorization: <JWT>

204 No Content  → success
404             → {"message": "Task not found"}
```

## What I Learned

**Challenge: DynamoDB Key Design**
When initially designing the database schema, I tried using auto-incrementing integer IDs, which is standard practice in relational databases like MySQL or PostgreSQL. DynamoDB does not support auto-increment because it is a distributed system where sequential ID generation would create a bottleneck. Switching to UUID-based partition keys resolved the issue and provided globally unique identifiers without coordination between nodes. This experience reinforced that NoSQL databases require fundamentally different design patterns than relational databases, particularly around key selection and data modeling.

**Challenge: API Gateway Path Parameter Extraction**
After deploying the API, requests to individual task endpoints like /tasks/{id} returned errors because the Lambda function could not extract the task ID from the request. The issue was that API Gateway proxy integration passes the entire HTTP request as a single event object rather than pre-parsing path parameters into discrete variables. Building a helper function to parse the request path and extract the ID from the last URL segment resolved the issue. This highlighted the difference between proxy integration (raw request passthrough) and non-proxy integration (pre-parsed parameters) in API Gateway.

**Challenge: CORS Configuration Across Two Layers**
During frontend integration testing, the browser blocked all API requests with CORS errors despite having configured CORS headers in the Lambda response. The root cause was that CORS requires configuration at two separate layers. API Gateway must handle OPTIONS preflight requests and return proper Access-Control headers, AND the Lambda function must include CORS headers in every response. Configuring only one layer is insufficient because the browser sends a preflight OPTIONS request before the actual request, and both must return valid CORS headers.

**Challenge: DynamoDB Scan at Scale**
The initial list implementation used a full-table Scan on every request. At hundreds of items this was fine, but Scan reads every item in the table — at thousands of records it becomes slow and expensive, and Scan consumes capacity proportional to table size rather than result size. Adding a Global Secondary Index on `entity_type + created_at` and switching to Query resolved this. The GSI allows DynamoDB to jump directly to the right partition and return results sorted by creation time, with cost and latency scaling only with the page size.

**Challenge: Pagination Token Leaking Internal Schema**
The initial implementation returned the raw DynamoDB `LastEvaluatedKey` as the pagination cursor. This object contains the actual key attribute names and types (`{"id": {"S": "abc-123"}}`), leaking internal database schema to API clients. Base64-encoding the key before returning it keeps the cursor opaque — clients treat it as an unreadable string, and the database schema remains an implementation detail.

**Challenge: Double Round Trips on Write Operations**
Update and delete initially made two DynamoDB calls: a `GetItem` to check existence, then the actual write. Two calls means two potential failure points, double the latency, and double the cost. Switching to `ConditionExpression="attribute_exists(id)"` on the write operation itself collapses this to a single atomic call. If the item does not exist, DynamoDB raises `ConditionalCheckFailedException` which maps to a 404 response — the same result in one round trip.

**Skills Developed**
Gained practical experience designing serverless architectures with event-driven compute and NoSQL data stores. Developed proficiency in DynamoDB access patterns including GSI design, conditional writes, and cursor-based pagination. Improved understanding of API Gateway integration types, Cognito JWT authorization, CORS mechanics, and request throttling. Strengthened Terraform skills through modular design, environment-prefixed resource naming, and deployment triggers for zero-downtime redeploys. Deepened knowledge of production observability: structured logging, X-Ray distributed tracing, CloudWatch metric alarms, and SNS alerting.

## Troubleshooting

**401 Unauthorized**
Include a valid Cognito JWT in the `Authorization` header. Tokens expire after 1 hour — re-authenticate using `initiate-auth` to get a fresh token. Confirm the Cognito user pool ID and client ID in your request match the Terraform outputs.

**Lambda Returns "Handler Not Found"**
Verify the handler in Terraform matches the Python file and function name (`task_manager.handler`). Confirm the Lambda zip contains the Python file at the root level, not inside a subdirectory. Repackage with `./scripts/package.sh` and redeploy.

**API Returns 502 Bad Gateway**
The Lambda function is crashing. Check CloudWatch Logs:
```
aws logs tail /aws/lambda/serverless-task-api-dev-task-manager --follow
```
Common causes: missing `TABLE_NAME` environment variable, incorrect IAM permissions, or a Python import error in the deployment package.

**CORS Errors in Browser Console**
OPTIONS preflight must return `Access-Control-Allow-Origin` from API Gateway, and all Lambda responses must include the same header. Test with curl first (which ignores CORS) to confirm the API works, then debug the CORS headers separately. Ensure `cors_origin` in `terraform.tfvars` matches your frontend domain exactly.

**DynamoDB Returns Access Denied**
The Lambda execution role is missing permissions. Confirm the IAM policy includes `dynamodb:Query`, `dynamodb:GetItem`, `dynamodb:PutItem`, `dynamodb:UpdateItem`, and `dynamodb:DeleteItem`, and that the resource ARN covers both the table and its indexes (`arn:aws:dynamodb:*:*:table/*/index/*`).

**Lambda Throttle Alarm Firing**
The reserved concurrency limit (50) is being hit. Either traffic is higher than expected, or a slow DynamoDB response is holding executions open longer than normal. Check X-Ray traces for latency spikes. Raise `reserved_concurrency` in `terraform.tfvars` if traffic warrants it.

**Tasks Not Persisting After Creation**
Verify the DynamoDB table name matches the `TABLE_NAME` Lambda environment variable. Run `aws dynamodb list-tables` to confirm the table exists. Check CloudWatch Logs for `PutItem` errors. If writes fail, the issue is likely an IAM permission or table name mismatch.

## Cost Analysis

**Development and Testing**
Zero monthly cost under AWS Free Tier. Lambda provides 1 million free requests and 400,000 GB-seconds per month. API Gateway includes 1 million free requests. DynamoDB offers 25 GB of storage. CloudWatch includes 5 GB of log ingestion.

**Production Costs**

| Component | Free Tier | Cost After Free Tier |
|-----------|-----------|----------------------|
| API Gateway | 1M requests/month | $3.50 per million requests |
| Lambda | 1M requests, 400K GB-seconds | $0.20 per million requests |
| DynamoDB | 25 GB storage | $1.25 per million reads/writes |
| Cognito | 50,000 MAUs | $0.0055 per MAU after |
| CloudWatch Logs | 5 GB ingestion | $0.50 per GB |
| X-Ray | 100K traces/month | $5.00 per million traces |
| SNS | 1M notifications | $0.50 per million |

**Usage Scenario Estimates**

| Scenario | Monthly Requests | Monthly Cost |
|----------|-----------------|-------------|
| Hobby / Development | 3,000 | $0 |
| Light Production | 100,000 | $1.00 |
| Medium Production | 1,000,000 | $5.50 |

**Comparison to Traditional Architecture**
Running equivalent functionality on a t3.small EC2 instance with an RDS db.t3.micro database costs approximately $25 per month regardless of traffic. This serverless implementation provides the same functionality at $0–$5.50 per month depending on usage — 78–100% cost savings with no server management.

## Security Considerations

**Authentication**
All endpoints except CORS preflight (`OPTIONS`) require a Cognito-issued JWT. Tokens are validated by API Gateway before Lambda is invoked — unauthorized requests are rejected at the edge with no Lambda cost. Cognito enforces password complexity (uppercase, lowercase, numbers, symbols, 8+ characters) and requires email verification.

**Authorization**
Lambda IAM policy is scoped to specific DynamoDB actions on the specific table and its indexes. No wildcard actions or resources. X-Ray write access uses the AWS-managed `AWSXRayDaemonWriteAccess` policy. No hardcoded credentials exist anywhere in application code or Terraform configuration.

**Network**
API Gateway is the only public-facing endpoint. Lambda executes in AWS-managed infrastructure with no direct internet exposure. DynamoDB communication occurs over AWS internal networks using IAM-based authentication. All API traffic is encrypted in transit via HTTPS.

**Data Protection**
DynamoDB encrypts all data at rest using AWS-managed keys. Point-in-time recovery is enabled — data can be restored to any second within the last 35 days. Pagination cursors are base64-encoded to avoid exposing internal database schema. Input length limits (1000 characters) prevent oversized payloads.

**CORS**
Configure `cors_origin` in `terraform.tfvars` to your frontend domain. The default `*` is suitable for development only. Production deployments should set a specific origin to prevent other websites from making authenticated requests on behalf of your users.

**Throttling**
API Gateway enforces 100 req/s sustained and 200 burst. Lambda reserved concurrency caps at 50 concurrent executions. Both limits prevent a single client or traffic spike from exhausting capacity or running up unbounded costs.

## Future Enhancements

Implement user-scoped task isolation using the Cognito `sub` claim as a secondary key — currently all authenticated users can read and modify all tasks. Add PATCH support for partial updates rather than full-replacement PUT. Configure API Gateway response caching for read-heavy workloads. Add CI/CD pipeline with GitHub Actions for automated testing and deployment on push. Implement DynamoDB Streams with a Lambda trigger for event-driven processing such as completion notifications. Add AWS WAF rules on API Gateway for SQL injection and XSS protection. Configure a custom domain with ACM certificate for a stable, human-readable API endpoint.

## Production Readiness Checklist

**Implemented**
- JWT authentication via Cognito User Pool on all endpoints
- API Gateway throttling: 100 req/s rate, 200 burst
- API Gateway structured access logs with 30-day retention
- DynamoDB GSI for efficient list queries (no full-table scans)
- DynamoDB point-in-time recovery
- Lambda reserved concurrency (50) to cap blast radius
- Lambda X-Ray active tracing
- Lambda structured JSON logs with 30-day retention
- Five CloudWatch metric alarms with SNS email alerting
- Atomic conditional writes (single round trip on update/delete)
- Opaque base64 pagination tokens
- Input validation: required fields, length limits, enum values
- Correct HTTP status codes (201, 204, 404, 405, 409)
- IAM least-privilege policies scoped to specific resources
- Safe deploy script: plan-then-confirm, no auto-approve
- Environment-prefixed resource names for multi-env support
- Remote Terraform state with S3 + DynamoDB locking

**Remaining for Full Production**
- User-scoped task isolation (per-user data partitioning)
- Custom domain with ACM SSL certificate
- CI/CD pipeline with automated integration tests
- AWS WAF on API Gateway
- Multi-region with DynamoDB Global Tables for disaster recovery

## Teardown

To destroy all infrastructure:
```
cd scripts
./teardown.sh
```

Or manually:
```
cd infrastructure
terraform destroy
```

This permanently deletes the DynamoDB table and all stored tasks, the Lambda function, the API Gateway, Cognito user pool, IAM roles, CloudWatch log groups, and SNS topic.

## License

MIT License. See LICENSE file for details.

## Author

Steven Lewis
AWS Solutions Architect Associate
AWS Cloud Practitioner
GitHub: github.com/sjlewis25
LinkedIn: linkedin.com/in/steven-lewis-fl

## Acknowledgments

Built as part of cloud engineering skills development. Serverless architecture patterns inspired by the AWS Well-Architected Framework Serverless Application Lens.
