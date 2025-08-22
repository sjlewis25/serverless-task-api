# Serverless Task API

A serverless backend system that allows users to create and retrieve task data through a lightweight API. Designed using core AWS services and built to solve the problem of manual, repetitive task tracking with scalable, cost-efficient infrastructure.

## Problem

Manual task tracking through spreadsheets or static tools is slow, error-prone, and not scalable. There’s no easy way to expose task data via API without overengineering a backend or maintaining servers.

## Solution

This project delivers a fully serverless API built on AWS using Lambda, API Gateway, and DynamoDB. Infrastructure is provisioned through Terraform, and all packaging and deployment is handled with Bash scripting for simplicity and repeatability.

## Architecture

- API Gateway: Exposes RESTful endpoints for HTTP access  
- AWS Lambda (Python): Executes the logic for handling GET and POST requests  
- DynamoDB: Stores and retrieves task data in a NoSQL table  
- Terraform: Provisions all infrastructure as code  
- Bash Scripts: Automate Lambda packaging, deployment, and teardown  
- IAM: Secures access via tightly scoped roles and policies  

## Business Value

- Eliminates the need to manually track tasks in spreadsheets  
- Enables instant task creation and retrieval through HTTP requests  
- Serverless architecture minimizes cost (near $0 when idle)  
- Provides a practical, reproducible example of infrastructure automation  
- Makes it easy to reuse and extend for other serverless backend needs  

## Folder Structure

.
├── README.md  
├── infrastructure/  
│   ├── main.tf  
│   ├── outputs.tf  
│   ├── variables.tf  
│   └── modules/  
│       └── lambda/  
│           ├── main.tf  
│           ├── outputs.tf  
│           └── variables.tf  
├── lambda/  
│   ├── task_manager.py  
│   └── utils/  
│       └── response.py  
├── scripts/  
│   ├── package.sh  
│   ├── deploy.sh  
│   └── teardown.sh  
├── .gitignore

## Prerequisites

- AWS CLI with active credentials  
- Terraform installed  
- Python 3.x  
- Bash terminal (Linux, macOS, or Git Bash on Windows)

## How to Use

### 1. Package the Lambda Function

    bash scripts/package.sh

Creates a zip file from the `lambda/` folder and copies it into the Lambda module path for Terraform.

### 2. Deploy Infrastructure

    bash scripts/deploy.sh

Initializes Terraform, applies the infrastructure plan, and deploys the Lambda function. Outputs the API Gateway URL.

### 3. Test the API

Replace `<invoke_url>` with the output from deployment.

Get all tasks:

    curl <invoke_url>/tasks

Post a new task:

    curl -X POST <invoke_url>/tasks \
         -H "Content-Type: application/json" \
         -d '{"task": "Write README"}'

### 4. Tear Down Infrastructure

    bash scripts/teardown.sh

Destroys all provisioned infrastructure using Terraform.

## Outputs After Deploy

- `invoke_url`: API Gateway endpoint  
- `lambda_function_name`  
- `lambda_function_arn`

## Future Improvements

- Add authentication with Cognito  
- Support pagination and filtering  
- Add structured logging and CloudWatch alarms  
- Support deployment across multiple environments (dev/test/prod)  
- Estimate and track infrastructure costs
- Develop front-end for users
- Integrate CI/CD pipeline using GitHub Actions for automatic deploys


## Author

**Steven Lewis**  
Cloud Engineer | AWS | Terraform | Python  
GitHub: [sjlewis25](https://github.com/sjlewis25)
