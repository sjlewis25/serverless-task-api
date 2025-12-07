# Serverless Task API

A production-ready serverless REST API built with AWS Lambda, API Gateway, and DynamoDB, provisioned entirely with Terraform. Demonstrates serverless architecture patterns, infrastructure as code, and full CRUD operations with zero server management.

![Architecture](architecture-diagram.png)

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [API Endpoints](#api-endpoints)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Deployment](#deployment)
- [Testing](#testing)
- [Cost Estimate](#cost-estimate)
- [Security Considerations](#security-considerations)
- [Lessons Learned](#lessons-learned)
- [Future Enhancements](#future-enhancements)
- [Author](#author)

---

## Overview

This project showcases a serverless application architecture using AWS managed services. The API provides task management functionality with automatic scaling, pay-per-use pricing, and no infrastructure to maintain.

**What it demonstrates:**
- Serverless architecture design patterns
- Infrastructure as code with Terraform
- RESTful API design with proper HTTP methods
- AWS service integration (Lambda, API Gateway, DynamoDB)
- Error handling and input validation
- CORS configuration for web integration
- IAM security with least-privilege policies

---

## Architecture

### Components

**API Gateway**
- RESTful HTTP endpoints with request validation
- CORS enabled for web application integration
- Integrated with AWS Lambda via proxy integration

**AWS Lambda**
- Python 3.11 runtime
- Event-driven execution model
- Automatic scaling based on demand
- CloudWatch logging integrated

**DynamoDB**
- NoSQL database with on-demand billing
- Single-table design with `id` as partition key
- Supports high-throughput read/write operations

**Terraform**
- Infrastructure as code for reproducible deployments
- Modular design for reusability
- Remote state management ready

### Data Flow
```
Client Request
    ↓
API Gateway (Validate & Route)
    ↓
Lambda Function (Process Logic)
    ↓
DynamoDB (Store/Retrieve Data)
    ↓
Lambda Function (Format Response)
    ↓
API Gateway (Return to Client)
```

---

## Features

✅ **Full CRUD Operations**
- Create tasks with validation
- Read all tasks with pagination
- Read individual tasks by ID
- Update existing tasks
- Delete tasks

✅ **Serverless Architecture**
- Zero server management
- Automatic scaling
- Pay-per-request pricing

✅ **Production-Ready Code**
- Comprehensive error handling
- Input validation
- Structured logging
- HTTP status codes following REST standards

✅ **Infrastructure as Code**
- Complete Terraform configuration
- Modular Lambda deployment
- Environment-based configuration

✅ **Security**
- IAM least-privilege policies
- Secrets managed via environment variables
- CORS properly configured

---

## Tech Stack

**Cloud Services:**
- AWS Lambda (Python 3.11)
- Amazon API Gateway (REST API)
- Amazon DynamoDB (NoSQL Database)
- AWS IAM (Security & Permissions)
- Amazon CloudWatch (Logging & Monitoring)

**Infrastructure:**
- Terraform 1.0+
- Bash scripting

**Development:**
- Python 3.11
- Boto3 (AWS SDK)

---

## API Endpoints

### List All Tasks
```http
GET /tasks
```

**Query Parameters:**
- `limit` (optional): Number of tasks to return (1-100, default: 25)
- `next` (optional): Pagination token for next page

**Response:**
```json
{
  "items": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "task": "Deploy infrastructure",
      "status": "new",
      "priority": "high",
      "created_at": 1703001234,
      "updated_at": 1703001234
    }
  ],
  "count": 1,
  "next": null
}
```

---

### Get Single Task
```http
GET /tasks/{id}
```

**Response:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "task": "Deploy infrastructure",
  "status": "new",
  "priority": "high",
  "created_at": 1703001234,
  "updated_at": 1703001234
}
```

**Error Response (404):**
```json
{
  "message": "Task not found"
}
```

---

### Create Task
```http
POST /tasks
Content-Type: application/json
```

**Request Body:**
```json
{
  "task": "Write documentation",
  "status": "new",
  "priority": "medium"
}
```

**Response (201 Created):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "task": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "task": "Write documentation",
    "status": "new",
    "priority": "medium",
    "created_at": 1703001234,
    "updated_at": 1703001234
  }
}
```

**Validation Rules:**
- `task` (required): Non-empty string
- `status` (optional): One of `new`, `in_progress`, `completed`, `cancelled`
- `priority` (optional): One of `low`, `medium`, `high`, `urgent`

---

### Update Task
```http
PUT /tasks/{id}
Content-Type: application/json
```

**Request Body (all fields optional):**
```json
{
  "task": "Updated task description",
  "status": "in_progress",
  "priority": "urgent"
}
```

**Response (200 OK):**
```json
{
  "message": "Task updated successfully",
  "task": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "task": "Updated task description",
    "status": "in_progress",
    "priority": "urgent",
    "created_at": 1703001234,
    "updated_at": 1703001500
  }
}
```

**Error Response (404):**
```json
{
  "message": "Task not found"
}
```

---

### Delete Task
```http
DELETE /tasks/{id}
```

**Response (200 OK):**
```json
{
  "message": "Task deleted successfully",
  "id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Error Response (404):**
```json
{
  "message": "Task not found"
}
```

---

## Project Structure
```
.
├── infrastructure/               # Terraform configuration
│   ├── main.tf                  # Core infrastructure resources
│   ├── outputs.tf               # Output values (API endpoint)
│   ├── variables.tf             # Input variables
│   └── modules/
│       └── lambda/              # Lambda module
│           ├── main.tf          # Lambda function definition
│           ├── variables.tf     # Module variables
│           └── outputs.tf       # Module outputs
│
├── lambda/                       # Python application code
│   ├── task_manager.py          # Main Lambda handler
│   └── utils/
│       └── response.py          # Response formatting utilities
│
├── scripts/                      # Deployment automation
│   ├── package.sh               # Package Lambda deployment
│   ├── deploy.sh                # Deploy infrastructure
│   └── teardown.sh              # Destroy resources
│
├── task-ui/                      # React frontend (optional)
│   ├── src/
│   └── public/
│
├── .gitignore
└── README.md
```

---

## Prerequisites

- **AWS Account** with appropriate permissions
- **AWS CLI** configured with credentials
- **Terraform** 1.0 or later
- **Python** 3.11+
- **Bash** shell (Linux, macOS, or Git Bash on Windows)

---

## Installation

### 1. Clone the Repository
```bash
git clone https://github.com/sjlewis25/serverless-task-api.git
cd serverless-task-api
```

### 2. Configure AWS Credentials
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Set default region (e.g., us-east-1)
```

### 3. Verify Prerequisites
```bash
# Check Terraform
terraform version

# Check Python
python3 --version

# Check AWS CLI
aws sts get-caller-identity
```

---

## Deployment

### Option 1: Automated Deployment (Recommended)
```bash
# Navigate to scripts directory
cd scripts

# Package Lambda function
./package.sh

# Deploy infrastructure
./deploy.sh
```

The deployment script will:
1. Initialize Terraform
2. Create deployment plan
3. Deploy all AWS resources
4. Output the API Gateway endpoint URL

**Expected output:**
```
Outputs:

api_endpoint = "https://abc123xyz.execute-api.us-east-1.amazonaws.com/dev"
```

---

### Option 2: Manual Deployment
```bash
# Package Lambda function
cd lambda
zip -r ../infrastructure/modules/lambda/task_manager.zip .
cd ..

# Deploy with Terraform
cd infrastructure
terraform init
terraform plan
terraform apply

# Save the API endpoint
terraform output api_endpoint
```

---

## Testing

### Using cURL
```bash
# Set API endpoint (replace with your output)
export API_URL="https://abc123xyz.execute-api.us-east-1.amazonaws.com/dev"

# Create a task
curl -X POST $API_URL/tasks \
  -H "Content-Type: application/json" \
  -d '{"task": "Test deployment", "priority": "high"}'

# Save the returned task ID
export TASK_ID="<paste-task-id-here>"

# List all tasks
curl $API_URL/tasks

# Get specific task
curl $API_URL/tasks/$TASK_ID

# Update task
curl -X PUT $API_URL/tasks/$TASK_ID \
  -H "Content-Type: application/json" \
  -d '{"status": "in_progress", "priority": "urgent"}'

# Delete task
curl -X DELETE $API_URL/tasks/$TASK_ID

# Verify deletion (should return 404)
curl $API_URL/tasks/$TASK_ID
```

---

### Using Postman

1. Import the API endpoint: `{{api_url}}/tasks`
2. Set environment variable `api_url` to your API Gateway URL
3. Test each endpoint with the request bodies shown above

---

### Using Python
```python
import requests
import json

API_URL = "https://abc123xyz.execute-api.us-east-1.amazonaws.com/dev"

# Create task
response = requests.post(
    f"{API_URL}/tasks",
    json={"task": "Test from Python", "priority": "medium"}
)
task = response.json()
task_id = task['id']

# Get task
response = requests.get(f"{API_URL}/tasks/{task_id}")
print(response.json())

# Update task
response = requests.put(
    f"{API_URL}/tasks/{task_id}",
    json={"status": "completed"}
)
print(response.json())

# Delete task
response = requests.delete(f"{API_URL}/tasks/{task_id}")
print(response.json())
```

---

## Cost Estimate

This infrastructure costs approximately **$0-2/month** for personal/hobby use:

| Service | Free Tier | Cost After Free Tier |
|---------|-----------|---------------------|
| **API Gateway** | 1M requests/month | $3.50 per million requests |
| **Lambda** | 1M requests/month<br>400,000 GB-seconds compute | $0.20 per million requests<br>$0.0000166667 per GB-second |
| **DynamoDB** | 25 GB storage<br>25 read/write units | $1.25 per million reads<br>$1.25 per million writes |
| **CloudWatch Logs** | 5 GB ingestion | $0.50 per GB |

**Example Usage Costs:**

**Hobby Usage** (100 requests/day):
- API Gateway: Free tier
- Lambda: Free tier
- DynamoDB: Free tier
- **Total: $0/month**

**Light Production** (100,000 requests/month):
- API Gateway: Free tier
- Lambda: Free tier
- DynamoDB: ~$0.25
- CloudWatch: ~$0.50
- **Total: ~$0.75/month**

**Medium Production** (1M requests/month):
- API Gateway: Free tier
- Lambda: Free tier
- DynamoDB: ~$2.50
- CloudWatch: ~$2.00
- **Total: ~$4.50/month**

---

## Infrastructure Details

### Lambda Configuration
```hcl
Runtime: Python 3.11
Memory: 256 MB (configurable)
Timeout: 30 seconds
Concurrent Executions: 10 (configurable)
```

### DynamoDB Configuration
```hcl
Billing Mode: PAY_PER_REQUEST (on-demand)
Primary Key: id (String)
Attributes: Flexible schema (NoSQL)
```

### IAM Permissions

Lambda execution role includes:
- `logs:CreateLogGroup` - CloudWatch log group creation
- `logs:CreateLogStream` - Log stream management
- `logs:PutLogEvents` - Write logs
- `dynamodb:GetItem` - Read single item
- `dynamodb:PutItem` - Create/replace item
- `dynamodb:Scan` - List all items
- `dynamodb:UpdateItem` - Modify existing item
- `dynamodb:DeleteItem` - Remove item

---

## Monitoring

### CloudWatch Metrics

**Lambda Metrics:**
- Invocation count
- Error rate
- Duration (latency)
- Throttles

**API Gateway Metrics:**
- Request count
- 4XX errors (client errors)
- 5XX errors (server errors)
- Latency

### View Logs
```bash
# Tail Lambda logs in real-time
aws logs tail /aws/lambda/task-manager --follow

# Query specific errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/task-manager \
  --filter-pattern "ERROR"
```

---

## Security Considerations

### Current Implementation

✅ **IAM-based authentication** between AWS services
✅ **Least-privilege IAM policies** for Lambda
✅ **Environment variables** for configuration
✅ **CloudWatch logging** for audit trail
✅ **Input validation** for all API requests
✅ **CORS properly configured** for web integration

### Production Enhancements

For production deployment, consider adding:

**Authentication & Authorization:**
- AWS Cognito for user authentication
- API Gateway API keys for rate limiting
- OAuth 2.0 / JWT token validation

**Network Security:**
- VPC endpoints for private Lambda-to-DynamoDB communication
- AWS WAF rules on API Gateway to block common attacks
- Request throttling and rate limiting

**Data Security:**
- DynamoDB encryption at rest (enabled by default)
- Encryption in transit via HTTPS
- Sensitive data encryption with AWS KMS

**Monitoring & Compliance:**
- AWS CloudTrail for API call auditing
- GuardDuty for threat detection
- AWS Config for compliance monitoring

---

## Lessons Learned

### Challenge 1: DynamoDB Key Design

**Problem:** Initially tried using auto-incrementing IDs (SQL thinking)

**Solution:** Switched to UUID-based IDs which are more DynamoDB-friendly

**Lesson:** NoSQL databases require different design patterns than relational databases. UUIDs work better for distributed systems.

---

### Challenge 2: API Gateway Path Parameters

**Problem:** Lambda couldn't extract task ID from `/tasks/{id}` path

**Solution:** Created helper function to parse path and extract ID from the last segment

**Lesson:** AWS Lambda proxy integration passes the entire request object; you need to parse path parameters manually.

---

### Challenge 3: CORS Configuration

**Problem:** Frontend couldn't call API due to CORS restrictions

**Solution:** Added OPTIONS method with proper CORS headers in API Gateway

**Lesson:** When building APIs for web frontends, CORS must be configured on BOTH the API Gateway OPTIONS method AND Lambda response headers.

---

### Challenge 4: Lambda Handler Naming

**Problem:** Initial deployment failed with "Handler not found" error

**Solution:** Aligned handler name in Terraform (`task_manager.handler`) with actual Python function name

**Lesson:** The Lambda handler format is `filename.function_name`. Terraform must match the actual code structure.

---

### Challenge 5: Environment Variables

**Problem:** Lambda couldn't find DynamoDB table name

**Solution:** Passed table name as environment variable through Terraform module

**Lesson:** Never hardcode resource names. Use Terraform outputs and environment variables for configuration.

---

## Teardown

To destroy all infrastructure and avoid ongoing costs:
```bash
cd scripts
./teardown.sh
```

Or manually with Terraform:
```bash
cd infrastructure
terraform destroy
```

**Warning:** This will permanently delete:
- The DynamoDB table and all tasks
- The Lambda function
- The API Gateway
- All CloudWatch logs (after retention period)

---

## Future Enhancements

### Features
- [ ] Task categories and tags
- [ ] Due dates and reminders
- [ ] Task assignment to users
- [ ] File attachments via S3
- [ ] Task comments and activity history

### Authentication
- [ ] AWS Cognito user pools
- [ ] API key management
- [ ] Role-based access control (RBAC)

### Operations
- [ ] CloudWatch dashboards for visualization
- [ ] SNS alerts for Lambda errors
- [ ] X-Ray for distributed tracing
- [ ] Automated testing with Pytest
- [ ] CI/CD pipeline with GitHub Actions

### Performance
- [ ] DynamoDB auto-scaling for high traffic
- [ ] API Gateway caching
- [ ] Lambda reserved concurrency
- [ ] DynamoDB Global Tables for multi-region

---

## Why This Project

I built this to demonstrate:

**Serverless Architecture** - No servers to manage, automatic scaling, pay-per-use pricing

**Infrastructure as Code** - Reproducible deployments, version-controlled infrastructure

**AWS Service Integration** - API Gateway, Lambda, and DynamoDB working together seamlessly

**Production Thinking** - Error handling, validation, monitoring, security, cost optimization

**Full-Stack Capability** - Backend API with optional frontend integration

This project serves as a foundation for building scalable serverless applications and demonstrates practical cloud engineering skills.

---

## Related Projects

- [Business Automation System](https://github.com/sjlewis25/Business-Automation-System) - Three-tier AWS architecture with VPC, EC2, RDS
- [EC2 Auto-Remediation](https://github.com/sjlewis25/ec2-auto-remediation) - Event-driven automation with EventBridge and Lambda
- [Docker CI/CD Pipeline](https://github.com/sjlewis25/AWS-Docker-CICD) - Containerized deployments with ECS Fargate

---

## Author

**Steven Lewis**
- Cloud Engineer | AWS Certified Solutions Architect
- GitHub: [@sjlewis25](https://github.com/sjlewis25)
- LinkedIn: [steven-lewis-fl](https://linkedin.com/in/steven-lewis-fl)
- Email: steven.j.lewis.2024@gmail.com

---

## License

This project is open source and available for educational purposes.

---

## Acknowledgments

Built with AWS serverless technologies and Terraform as part of a cloud engineering portfolio.
