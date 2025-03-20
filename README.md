# Serverless Task Management API 🚀

## Overview
A fully serverless task management API built with **AWS Lambda, API Gateway, and DynamoDB**, deployed using **Terraform**.

## 🛠 Tech Stack
- AWS Lambda (Backend)
- API Gateway (Routing)
- DynamoDB (Database)
- Terraform (Infrastructure as Code)
- AWS CLI (Deployment & API Testing)

## 🚀 Setup Instructions
1. Clone the repo:
   ```bash
   git clone https://github.com/sjlewis25/serverless-task-api.git
   cd serverless-task-api
   ```
2. Deploy with Terraform:
   ```bash
   terraform init
   terraform apply -auto-approve
   ```
3. Invoke the API:
   ```bash
   aws lambda invoke --function-name taskManagerLambda --payload fileb://payload.json response.json --log-type Tail
   ```

## 📌 API Endpoints
| Method | Endpoint | Description |
|--------|---------|-------------|
| `POST` | `/tasks` | Create a new task |

## 👨‍💻 Author
Steve Lewis  
- [LinkedIn](https://www.linkedin.com/in/steve-lewis-640141345/))  
 
