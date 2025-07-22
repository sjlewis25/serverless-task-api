# Serverless Task API

This is a serverless task management API built on AWS. It uses Lambda for compute, API Gateway for HTTP access, DynamoDB for storage, and Terraform for infrastructure management. Bash scripts automate the packaging, deployment, and teardown processes.

---

## What It Does

- Accepts HTTP GET and POST requests via API Gateway
- Processes tasks using a Python-based Lambda function
- Stores task data in a DynamoDB table
- Uses IAM roles and policies to secure access
- Deploys infrastructure and Lambda code with Terraform

---

## Folder Structure

```
Serverless-Task-Api/
│
├── infrastructure/             # Terraform config and modules
│   ├── main.tf
│   ├── outputs.tf
│   ├── variables.tf
│   └── modules/
│       └── lambda/
│           ├── main.tf
│           ├── outputs.tf
│           └── variables.tf
│
├── lambda/                     # Lambda function code
│   ├── task_manager.py
│   └── utils/
│       └── response.js
│
├── scripts/                    # Automation scripts
│   ├── package.sh              # Zips the Lambda function
│   ├── deploy.sh               # Deploys Terraform and Lambda
│   └── teardown.sh             # Destroys Terraform infrastructure
│
├── .gitignore
└── README.md
```

---

## Requirements

- AWS CLI configured
- Terraform installed
- Bash shell (macOS, Linux, or Git Bash for Windows)
- Python 3.x

---

## Usage

### 1. Package the Lambda Function

From the project root:

```bash
bash scripts/package.sh
```

This will zip the `lambda/` code and place it at `infrastructure/modules/lambda/task_manager.zip`.

---

### 2. Deploy Infrastructure

```bash
bash scripts/deploy.sh
```

This script initializes Terraform, applies the infrastructure, and deploys the Lambda function. When finished, it will print the API endpoint in the terminal.

---

### 3. Test the API

To get tasks:

```bash
curl https://<api-id>.execute-api.us-east-1.amazonaws.com/dev/tasks
```

To add a new task:

```bash
curl -X POST -H "Content-Type: application/json" -d '{"task": "Example task"}' https://<api-id>.execute-api.us-east-1.amazonaws.com/dev/tasks
```

Replace `<api-id>` with the actual value shown in the deployment output.

---

### 4. Tear Down

To destroy the entire infrastructure:

```bash
bash scripts/teardown.sh
```

This will run `terraform destroy` and clean up resources.

---

## Outputs

- `invoke_url` – API Gateway endpoint
- `lambda_function_name` – Name of the Lambda function
- `lambda_function_arn` – ARN for the Lambda function

---

## Notes

- All `.terraform` files are excluded from Git via `.gitignore`.
- Designed for individual development and learning purposes.
- Make sure your AWS credentials are set before running deployment.


## Author

**Steven Lewis**  
Cloud Engineer | AWS | Terraform | Python  
GitHub: [sjlewis25](https://github.com/sjlewis25)
