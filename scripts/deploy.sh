#!/bin/bash

# AWS Serverless Feedback App Deployment Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${1:-prod}
AWS_REGION=${2:-us-east-1}

echo -e "${GREEN}Starting deployment for environment: $ENVIRONMENT${NC}"

# Validate AWS credentials
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    exit 1
fi

# Run tests
echo -e "${YELLOW}Running tests...${NC}"
if command -v pytest &> /dev/null; then
    pytest tests/ -v
else
    echo -e "${YELLOW}Warning: pytest not found, skipping tests${NC}"
fi

# Lint Python code
echo -e "${YELLOW}Linting Python code...${NC}"
if command -v pylint &> /dev/null; then
    pylint backend/*.py --disable=C0114,C0116 || true
else
    echo -e "${YELLOW}Warning: pylint not found, skipping linting${NC}"
fi

# Navigate to terraform directory
cd terraform

# Initialize Terraform
echo -e "${YELLOW}Initializing Terraform...${NC}"
terraform init

# Validate Terraform configuration
echo -e "${YELLOW}Validating Terraform configuration...${NC}"
terraform validate

# Plan deployment
echo -e "${YELLOW}Planning deployment...${NC}"
terraform plan -var="environment=$ENVIRONMENT" -var="aws_region=$AWS_REGION"

# Ask for confirmation
read -p "Do you want to proceed with deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi

# Apply deployment
echo -e "${YELLOW}Applying deployment...${NC}"
terraform apply -var="environment=$ENVIRONMENT" -var="aws_region=$AWS_REGION" -auto-approve

# Get outputs
echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}Outputs:${NC}"
terraform output

# Update frontend configuration
API_URL=$(terraform output -raw api_gateway_url)
if [ ! -z "$API_URL" ]; then
    echo -e "${YELLOW}Updating frontend configuration...${NC}"
    sed -i.bak "s|API_BASE_URL: '.*'|API_BASE_URL: '$API_URL'|" ../frontend/config.js
    
    # Re-upload frontend files
    terraform apply -target=aws_s3_object.script_js -target=aws_s3_object.index_html -auto-approve
    
    echo -e "${GREEN}Frontend updated with API URL: $API_URL${NC}"
fi

# Run basic health check
echo -e "${YELLOW}Running health check...${NC}"
if curl -s -f "$API_URL/feedback" > /dev/null; then
    echo -e "${GREEN}Health check passed!${NC}"
else
    echo -e "${RED}Health check failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}Website URL: $(terraform output -raw website_url)${NC}"
echo -e "${GREEN}API URL: $API_URL${NC}"