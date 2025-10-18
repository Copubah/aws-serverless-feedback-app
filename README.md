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

## GitHub Actions CI/CD

### Automatic Testing
Tests run automatically on all pushes and pull requests. No setup required.

### Automatic Deployment
To enable automatic deployment to AWS:

1. Go to your GitHub repository Settings > Secrets and variables > Actions
2. Add these repository secrets:
   - `AWS_ACCESS_KEY_ID`: Your AWS access key
   - `AWS_SECRET_ACCESS_KEY`: Your AWS secret key

Once configured, pushes to the main branch will automatically deploy to AWS.

## Clean Up
```bash
terraform destroy
```