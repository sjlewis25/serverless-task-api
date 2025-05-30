# Serverless Task API (AWS + Terraform)

A fully serverless RESTful Task Management API built on AWS using Lambda, API Gateway, and DynamoDB — provisioned entirely with Terraform.

## Features

- `GET /tasks` – List all tasks  
- `POST /tasks` – Create a new task  
- Uses UUID for task IDs  
- Deployable via Terraform  
- Clean, modular project structure  
- Secure IAM roles with least-privilege access

## Architecture

- **AWS Lambda** – Serverless function to handle requests  
- **API Gateway** – Exposes REST endpoints  
- **DynamoDB** – NoSQL database to store tasks  
- **Terraform** – Infrastructure as Code  
- **PowerShell** – Used for packaging and zipping Lambda deployments

## Deploy the API

1. Clone the repo:  
   `git clone https://github.com/sjlewis25/serverless-task-api.git`  
   `cd serverless-task-api/infrastructure`

2. Initialize Terraform:  
   `terraform init`

3. Deploy:  
   `terraform apply`

4. When complete, grab the invoke URL from the output:  
   `terraform output invoke_url`

## Example Usage

**Create Task (POST)**  
`curl -X POST https://your-api-id.execute-api.us-east-1.amazonaws.com/dev/tasks \`  
`  -H "Content-Type: application/json" \`  
`  -d '{"title": "Finish documentation"}'`

**Get All Tasks (GET)**  
`curl https://your-api-id.execute-api.us-east-1.amazonaws.com/dev/tasks`

## Future Enhancements

- `PATCH /tasks/{id}` to mark task as completed  
- Input validation with JSON Schema  
- Custom domain + HTTPS  
- CI/CD pipeline for auto-deployment

## Author

**Steven Lewis**  
Cloud Engineer in training | AWS | Terraform | Python  
GitHub: [sjlewis25](https://github.com/sjlewis25)
