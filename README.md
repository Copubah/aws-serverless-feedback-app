# AWS Serverless Feedback Web Application

## Deployment Instructions

### Prerequisites
- AWS CLI configured with appropriate credentials
- Terraform installed (version 1.0+)

### Step 1: Deploy Infrastructure
```bash
cd terraform
terraform init
terraform apply
```

### Step 2: Update Frontend Configuration
After deployment, copy the API Gateway URL from the Terraform output:

```bash
terraform output api_gateway_url
```

Replace `YOUR_API_GATEWAY_URL` in `frontend/script.js` with the actual API endpoint URL.

### Step 3: Re-upload Frontend Files (if needed)
If you updated the frontend files after initial deployment:

```bash
terraform apply -target=aws_s3_object.script_js
```

### Step 4: Access Your Application
Use the website URL from Terraform output:

```bash
terraform output website_url
```

## Architecture
- DynamoDB: UserFeedback table with PAY_PER_REQUEST billing
- Lambda: Three functions (create, get, delete feedback)
- API Gateway: HTTP API with CORS enabled
- S3: Static website hosting
- IAM: Least-privilege roles and policies
- CloudWatch: Lambda function logging

## API Endpoints
- `POST /feedback` - Create new feedback
- `GET /feedback` - Retrieve all feedback
- `DELETE /feedback/{id}` - Delete feedback by ID

## Clean Up
```bash
terraform destroy
```