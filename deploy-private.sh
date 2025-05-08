#!/bin/bash
set -e

# Configuration
STACK_NAME="apigw-authz-private"
STAGE="dev"
REGION="us-east-1"  # Change to your preferred region
S3_BUCKET="apigw-authz-deployment-bucket"  # Change to your S3 bucket name

# VPC Configuration - Replace with your actual VPC details
VPC_ID=""
SUBNET_IDS=""
SECURITY_GROUP_IDS=""

# Check if VPC configuration is provided
if [ -z "$VPC_ID" ] || [ -z "$SUBNET_IDS" ] || [ -z "$SECURITY_GROUP_IDS" ]; then
    echo "Error: VPC configuration is required for private API deployment."
    echo "Please update the script with your VPC_ID, SUBNET_IDS, and SECURITY_GROUP_IDS."
    exit 1
fi

# Create S3 bucket if it doesn't exist
echo "Checking if S3 bucket exists..."
if ! aws s3 ls "s3://$S3_BUCKET" 2>&1 > /dev/null; then
    echo "Creating S3 bucket: $S3_BUCKET"
    aws s3 mb "s3://$S3_BUCKET" --region $REGION
fi

# Change to the private API directory
cd "$(dirname "$0")/private-api"

# Install dependencies for Lambda functions
echo "Installing dependencies for Lambda functions..."

# Customer data function
echo "Installing dependencies for customer data function..."
cd lambda/customer_data
pip install -r requirements.txt -t .
cd ../..

# Authorizer function
echo "Installing dependencies for authorizer function..."
cd lambda/authorizer
pip install -r requirements.txt -t .
cd ../..

# Package the CloudFormation template
echo "Packaging CloudFormation template..."
aws cloudformation package \
    --template-file template.yaml \
    --s3-bucket $S3_BUCKET \
    --s3-prefix $STACK_NAME \
    --output-template-file packaged.yaml \
    --region $REGION

# Deploy the CloudFormation stack
echo "Deploying CloudFormation stack: $STACK_NAME..."
aws cloudformation deploy \
    --template-file packaged.yaml \
    --stack-name $STACK_NAME \
    --parameter-overrides \
        Stage=$STAGE \
        VpcId=$VPC_ID \
        SubnetIds=$SUBNET_IDS \
        SecurityGroupIds=$SECURITY_GROUP_IDS \
    --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND \
    --region $REGION

# Get stack outputs
echo "Getting stack outputs..."
aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs" \
    --output table \
    --region $REGION

echo "Deployment completed successfully!"