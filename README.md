![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform)
![AWS](https://img.shields.io/badge/Cloud-AWS-FF9900?logo=amazon-aws)
![Lambda](https://img.shields.io/badge/Compute-Lambda-FF9900?logo=aws-lambda)
![DynamoDB](https://img.shields.io/badge/Database-DynamoDB-4053D6?logo=amazon-dynamodb)
![Python](https://img.shields.io/badge/Runtime-Python_3.11-3776AB?logo=python)

# Serverless Task API

Production-ready serverless REST API built with AWS Lambda, API Gateway, and DynamoDB. Deployed on AWS using Terraform for repeatable, infrastructure-as-code deployments.

## Problem Statement

Organizations building web applications need backend APIs to handle data operations, but traditional server-based architectures create significant operational overhead.

Running a dedicated EC2 instance or container cluster for a simple CRUD API costs $15 to $50 per month minimum, even during periods of zero traffic. These servers require patching, monitoring, and capacity planning. For small teams and early-stage applications, this represents wasted spend and engineering time on infrastructure that could be spent on product development.

Additionally, traditional architectures require manual scaling decisions. Underprovisioning leads to downtime during traffic spikes, while overprovisioning wastes money during quiet periods. Teams must choose between reliability and cost efficiency.

This project addresses these challenges by implementing a fully serverless architecture that scales automatically from zero to thousands of concurrent requests, costs nothing at idle, and eliminates all server management. The API handles full CRUD operations for task management while demonstrating serverless design patterns, proper error handling, and infrastructure as code practices. Total cost for typical development usage is $0 per month under AWS Free Tier.

## Architecture

![Architecture Diagram](architecture-diagram.png)

The API follows a serverless event-driven architecture with three layers.

**Request Routing Layer**
API Gateway receives incoming HTTP requests and performs initial validation. It routes requests to the appropriate Lambda function using proxy integration and handles CORS preflight requests for web application compatibility. API Gateway also provides request throttling and usage tracking.

**Business Logic Layer**
AWS Lambda executes the application code in response to API Gateway events. The function parses the incoming request, determines the operation (create, read, update, delete), validates input data, and interacts with the database. Lambda scales automatically based on demand, running zero instances when idle and spinning up concurrent executions during high traffic.

**Data Persistence Layer**
DynamoDB stores task records using a single-table design with UUID-based partition keys. On-demand billing mode means the database scales read and write capacity automatically without provisioning. DynamoDB provides single-digit millisecond response times for all operations.

**Component Flow**
```
Client Request → API Gateway (Validate and Route) → Lambda Function (Process Logic) → DynamoDB (Store/Retrieve)
                                                                                            ↓
Client Response ← API Gateway (Return Response) ← Lambda Function (Format Response) ←------┘
```

All infrastructure is provisioned through Terraform with modular configuration. The Lambda function is packaged and deployed via automated shell scripts.

## Technology Stack

**Core Components**
AWS Lambda serves as the compute layer running Python 3.11. Lambda was chosen over EC2 or ECS because the API workload is request-driven with variable traffic, making pay-per-invocation pricing significantly cheaper than always-on compute. Lambda also eliminates patching and capacity planning.

Amazon API Gateway provides the HTTP interface. It was selected for its native Lambda integration, built-in request throttling, and ability to handle CORS configuration at the infrastructure level rather than in application code.

Amazon DynamoDB stores task data as a NoSQL database. It was chosen over RDS because the task schema is simple and flexible, the access patterns are straightforward key-value lookups, and on-demand billing avoids paying for provisioned capacity during low-traffic periods. DynamoDB also eliminates database administration tasks like backups, patching, and connection pool management.

**Infrastructure and Deployment**
Terraform manages all AWS resource provisioning using a modular design. The Lambda function configuration is separated into its own module for reusability. Terraform creates the API Gateway, Lambda function, DynamoDB table, IAM roles, and CloudWatch log groups programmatically.

Boto3 (AWS SDK for Python) handles all DynamoDB operations within the Lambda function, including item creation with UUID generation, conditional updates, and paginated scans.

Bash scripts automate the packaging and deployment workflow, handling Lambda zip creation, Terraform initialization, and infrastructure provisioning in a single command.

## Key Features

**Full CRUD Operations**
Supports create, read, update, and delete operations for task management. Each operation includes input validation for required fields, status values (new, in_progress, completed, cancelled), and priority levels (low, medium, high, urgent). All responses follow REST conventions with appropriate HTTP status codes.

**Automatic Scaling**
Lambda scales from zero to thousands of concurrent executions based on incoming request volume. No capacity planning or scaling policies required. The API handles traffic spikes without configuration changes and costs nothing during periods of zero traffic.

**Pagination Support**
The list endpoint supports cursor-based pagination using DynamoDB's LastEvaluatedKey. Clients can specify a limit parameter (1 to 100 items, default 25) and use the returned next token to retrieve subsequent pages. This prevents large result sets from consuming excessive Lambda memory or causing client timeouts.

**Infrastructure as Code**
Complete Terraform configuration with modular Lambda deployment. Automated security configuration with least-privilege IAM policies. Reproducible infrastructure that can be deployed, destroyed, and redeployed in any AWS region using a single command.

**Cost Efficient**
The entire stack operates within AWS Free Tier for development and light production use, costing $0 per month for up to 1 million requests. Even at medium production volume of 1 million requests per month, total cost is approximately $4.50. This represents 90% or greater savings compared to running equivalent functionality on a dedicated EC2 instance.

## Deployment

**Prerequisites**
AWS Account with appropriate permissions
AWS CLI configured with credentials
Terraform version 1.0 or higher
Python 3.11 or later
Bash shell (Linux, macOS, or Git Bash on Windows)

**Local Setup**

Clone the repository and navigate to the project directory:
```
git clone https://github.com/sjlewis25/serverless-task-api.git
cd serverless-task-api
```

Verify all prerequisites are installed:
```
terraform version
python3 --version
aws sts get-caller-identity
```

**AWS Deployment (Automated)**

Package the Lambda function and deploy all infrastructure:
```
cd scripts
./package.sh
./deploy.sh
```

The deployment script initializes Terraform, creates a deployment plan, provisions all AWS resources, and outputs the API Gateway endpoint URL.

Expected output:
```
api_endpoint = "https://abc123xyz.execute-api.us-east-1.amazonaws.com/dev"
```

**AWS Deployment (Manual)**

Package the Lambda function:
```
cd lambda
zip -r ../infrastructure/modules/lambda/task_manager.zip .
cd ..
```

Deploy with Terraform:
```
cd infrastructure
terraform init
terraform plan
terraform apply
```

Retrieve the API endpoint:
```
terraform output api_endpoint
```

**Verify the Deployment**

Test the API by creating a task:
```
export API_URL="https://abc123xyz.execute-api.us-east-1.amazonaws.com/dev"

curl -X POST $API_URL/tasks \
  -H "Content-Type: application/json" \
  -d '{"task": "Test deployment", "priority": "high"}'
```

List all tasks to confirm data persistence:
```
curl $API_URL/tasks
```

## API Endpoints

**Create Task**
```
POST /tasks
Content-Type: application/json

Request Body:
{
  "task": "Write documentation",
  "status": "new",
  "priority": "medium"
}

Response (201 Created):
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

Validation: "task" is required and must be non-empty. "status" accepts new, in_progress, completed, or cancelled. "priority" accepts low, medium, high, or urgent.
```

**List All Tasks**
```
GET /tasks?limit=25&next=<pagination_token>

Response (200 OK):
{
  "items": [...],
  "count": 25,
  "next": "<pagination_token_or_null>"
}
```

**Get Single Task**
```
GET /tasks/{id}

Response (200 OK): Returns the task object.
Response (404 Not Found): {"message": "Task not found"}
```

**Update Task**
```
PUT /tasks/{id}
Content-Type: application/json

Request Body (all fields optional):
{
  "task": "Updated description",
  "status": "in_progress",
  "priority": "urgent"
}

Response (200 OK): Returns success message with updated task object.
Response (404 Not Found): {"message": "Task not found"}
```

**Delete Task**
```
DELETE /tasks/{id}

Response (200 OK): {"message": "Task deleted successfully", "id": "..."}
Response (404 Not Found): {"message": "Task not found"}
```

## What I Learned

**Challenge: DynamoDB Key Design**
When initially designing the database schema, I tried using auto-incrementing integer IDs, which is standard practice in relational databases like MySQL or PostgreSQL. DynamoDB does not support auto-increment because it is a distributed system where sequential ID generation would create a bottleneck. Switching to UUID-based partition keys resolved the issue and provided globally unique identifiers without coordination between nodes. This experience reinforced that NoSQL databases require fundamentally different design patterns than relational databases, particularly around key selection and data modeling.

**Challenge: API Gateway Path Parameter Extraction**
After deploying the API, requests to individual task endpoints like /tasks/{id} returned errors because the Lambda function could not extract the task ID from the request. The issue was that API Gateway proxy integration passes the entire HTTP request as a single event object rather than pre-parsing path parameters into discrete variables. Building a helper function to parse the request path and extract the ID from the last URL segment resolved the issue. This highlighted the difference between proxy integration (raw request passthrough) and non-proxy integration (pre-parsed parameters) in API Gateway.

**Challenge: CORS Configuration Across Two Layers**
During frontend integration testing, the browser blocked all API requests with CORS errors despite having configured CORS headers in the Lambda response. The root cause was that CORS requires configuration at two separate layers. API Gateway must handle OPTIONS preflight requests and return proper Access-Control headers, AND the Lambda function must include CORS headers in every response. Configuring only one layer is insufficient because the browser sends a preflight OPTIONS request before the actual request, and both must return valid CORS headers. Adding the OPTIONS method to API Gateway with appropriate headers alongside the existing Lambda response headers resolved the issue.

**Challenge: Lambda Handler Naming Convention**
The initial deployment failed immediately with a "Handler not found" error in CloudWatch logs. The Terraform configuration specified the handler as task_manager.handler, but the actual Python function was defined with a different name. The Lambda handler format follows the pattern filename.function_name, where both parts must exactly match the deployed code. Aligning the Terraform handler configuration with the actual Python file and function name resolved the error. This reinforced the importance of treating infrastructure configuration and application code as tightly coupled, where changes to one must be reflected in the other.

**Challenge: Hardcoded Resource Names**
The Lambda function initially failed to find the DynamoDB table because the table name was hardcoded in the Python code. When Terraform created the table with a different name based on the environment variable configuration, the function could not connect. Passing the table name as an environment variable through the Terraform module eliminated the dependency on hardcoded values. This experience demonstrated why infrastructure outputs should drive application configuration rather than the reverse, ensuring that resource names remain consistent across the entire deployment.

**Skills Developed**
Gained practical experience designing serverless architectures with event-driven compute and NoSQL data stores. Developed proficiency in DynamoDB single-table design patterns including partition key selection, on-demand capacity, and cursor-based pagination. Improved understanding of API Gateway integration types, CORS mechanics, and request routing. Strengthened Terraform skills through modular design with separate Lambda modules, variable passing between modules, and automated deployment scripting. Deepened knowledge of IAM least-privilege policies by crafting specific permissions for Lambda-to-DynamoDB and Lambda-to-CloudWatch interactions.

## Troubleshooting

**Lambda Returns "Handler Not Found"**
Verify the handler configuration in Terraform matches the Python file and function name. The format is filename.function_name, so task_manager.handler means Terraform expects a file called task_manager.py with a function called handler. Check that the Lambda zip package contains the Python file at the root level, not nested inside a subdirectory. Repackage using the package.sh script and redeploy.

**API Returns 502 Bad Gateway**
This indicates the Lambda function is crashing. Check CloudWatch logs for the specific error by running aws logs tail /aws/lambda/task-manager --follow. Common causes include missing environment variables (DynamoDB table name not set), incorrect IAM permissions (Lambda cannot access DynamoDB), or Python import errors in the deployment package. Verify environment variables are set in the Terraform Lambda module configuration.

**CORS Errors in Browser Console**
Confirm that both API Gateway and Lambda are configured for CORS. API Gateway must have an OPTIONS method on each resource path returning Access-Control-Allow-Origin, Access-Control-Allow-Methods, and Access-Control-Allow-Headers. Lambda responses must also include these headers. Test with curl first (which ignores CORS) to verify the API itself works, then debug CORS separately.

**DynamoDB Returns Access Denied**
The Lambda execution role is missing required DynamoDB permissions. Check the IAM policy attached to the Lambda role includes dynamodb:GetItem, dynamodb:PutItem, dynamodb:Scan, dynamodb:UpdateItem, and dynamodb:DeleteItem. Verify the policy's Resource ARN matches the actual DynamoDB table ARN. Run aws iam get-role-policy to inspect the current permissions.

**Tasks Not Persisting After Creation**
Verify the DynamoDB table exists and the Lambda environment variable points to the correct table name. Run aws dynamodb list-tables to confirm the table was created. Check CloudWatch logs for PutItem errors. If the table exists but writes fail, the issue is likely an IAM permission problem or a mismatch between the table name in the environment variable and the actual table name.

## Cost Analysis

**Development and Testing**
Zero monthly cost under AWS Free Tier. Lambda provides 1 million free requests and 400,000 GB-seconds of compute per month. API Gateway includes 1 million free requests. DynamoDB offers 25 GB of storage and 25 read/write capacity units. CloudWatch includes 5 GB of log ingestion. Typical development usage stays well within these limits.

**AWS Production Deployment**

| Component | Free Tier Included | Cost After Free Tier |
|-----------|-------------------|---------------------|
| API Gateway | 1M requests/month | $3.50 per million requests |
| Lambda | 1M requests, 400K GB-seconds | $0.20 per million requests |
| DynamoDB | 25 GB storage, 25 RCU/WCU | $1.25 per million reads/writes |
| CloudWatch Logs | 5 GB ingestion | $0.50 per GB |

**Usage Scenario Costs**

| Scenario | Monthly Requests | Monthly Cost |
|----------|-----------------|-------------|
| Hobby/Development | 3,000 | $0 |
| Light Production | 100,000 | $0.75 |
| Medium Production | 1,000,000 | $4.50 |

**Cost Optimization Strategies**
Use on-demand DynamoDB billing rather than provisioned capacity for unpredictable workloads. Configure Lambda memory at 256 MB rather than the default 128 MB, as the slight cost increase is offset by faster execution times that reduce billed duration. Set CloudWatch log retention to 14 days rather than indefinite to prevent storage cost accumulation. Use Lambda reserved concurrency to cap maximum simultaneous executions and prevent runaway costs from unexpected traffic spikes.

**Comparison to Traditional Architecture**
Running equivalent functionality on a t3.small EC2 instance with an RDS db.t3.micro database costs approximately $25 per month regardless of traffic volume. An ECS Fargate deployment with minimum capacity costs approximately $15 per month. This serverless implementation provides the same functionality at $0 to $4.50 per month depending on usage, representing 70 to 100% cost savings while eliminating all server management overhead.

## Security Considerations

**Network Security**
API Gateway provides the only public-facing endpoint. Lambda functions execute within AWS-managed VPC infrastructure with no direct internet exposure. DynamoDB communication occurs over AWS internal networks using IAM-based authentication rather than network-level access controls. All API traffic is encrypted in transit via HTTPS enforced by API Gateway.

**Data Protection**
DynamoDB encrypts all data at rest using AWS-managed encryption keys by default. Task data is stored with UUID-based identifiers that prevent enumeration attacks. Input validation on all API endpoints rejects malformed requests before they reach the database. CloudWatch logs provide a complete audit trail of all API invocations and Lambda executions.

**AWS IAM Best Practices**
Lambda execution role follows least-privilege principle with permissions scoped to specific DynamoDB actions (GetItem, PutItem, Scan, UpdateItem, DeleteItem) and specific CloudWatch actions (CreateLogGroup, CreateLogStream, PutLogEvents). No wildcard permissions are used. Resource ARNs are scoped to the specific DynamoDB table rather than account-wide access. No hardcoded credentials exist in application code or Terraform configuration.

## Future Enhancements

Add AWS Cognito user pool integration for user authentication and role-based access control, enabling multi-tenant task management with per-user data isolation. Implement API Gateway API keys with usage plans for rate limiting and client identification.

Configure CloudWatch dashboards for real-time API monitoring including invocation counts, error rates, latency percentiles, and DynamoDB consumed capacity. Add SNS alerting for Lambda error thresholds and sustained high latency.

Implement CI/CD pipeline using GitHub Actions to automate testing, Lambda packaging, and Terraform deployment on every push to main branch. Add automated integration tests using Pytest that validate all CRUD operations against a deployed test environment.

Enable AWS X-Ray distributed tracing to visualize request flow from API Gateway through Lambda to DynamoDB, enabling performance bottleneck identification and latency optimization.

Add DynamoDB Global Tables for multi-region replication to support disaster recovery and low-latency access from multiple geographic regions. Configure DynamoDB Streams with Lambda triggers for event-driven processing such as task completion notifications.

Implement API Gateway response caching with configurable TTL to reduce Lambda invocations and DynamoDB reads for frequently accessed task lists, improving response times and reducing costs for read-heavy workloads.

## Production Readiness Checklist

**Implemented**
- Full CRUD REST API with input validation and error handling
- Serverless architecture with automatic scaling and pay-per-use pricing
- Infrastructure as code with modular Terraform configuration
- IAM least-privilege policies for all service interactions
- CORS configuration for web application integration
- Automated deployment and teardown scripts
- Pagination support for large result sets
- CloudWatch logging for all Lambda executions

**Required for Production**
- Authentication and authorization via AWS Cognito or JWT validation
- API Gateway throttling and rate limiting with usage plans
- CI/CD pipeline for automated testing and deployment
- CloudWatch dashboards and SNS alerting for operational visibility
- DynamoDB backup strategy with point-in-time recovery enabled
- Custom domain name with SSL certificate for API endpoint
- Request/response logging with sensitive data masking
- Load testing to establish baseline performance metrics
- Web Application Firewall (WAF) rules on API Gateway

## Teardown

To destroy all infrastructure and avoid ongoing costs:
```
cd scripts
./teardown.sh
```

Or manually:
```
cd infrastructure
terraform destroy
```

This permanently deletes the DynamoDB table and all stored tasks, the Lambda function, the API Gateway, and all associated IAM roles and CloudWatch log groups.

## License

MIT License. See LICENSE file for details.

## Author

Steven Lewis
AWS Solutions Architect Associate
AWS Cloud Practitioner
GitHub: github.com/sjlewis25
LinkedIn: linkedin.com/in/steven-lewis-fl

## Acknowledgments

Built as part of cloud engineering skills development. Serverless architecture patterns inspired by AWS Well-Architected Framework and AWS Serverless Application Lens best practices.

## Acknowledgments

Built as part of cloud engineering skills development. Serverless architecture patterns inspired by AWS Well-Architected Framework and AWS Serverless Application Lens best practices.
This project is open source and available for educational purposes.

