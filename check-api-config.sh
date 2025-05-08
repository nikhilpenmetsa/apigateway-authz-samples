#!/bin/bash
set -e

# Configuration - Replace with your actual values
API_TYPE="regional"  # or "private"
REGION="us-east-1"
STAGE="dev"

# Get stack outputs
if [ "$API_TYPE" == "regional" ]; then
    STACK_NAME="apigw-authz-regional"
else
    STACK_NAME="apigw-authz-private"
fi

echo "Getting stack outputs..."
API_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs[?OutputKey=='ApiEndpoint'].OutputValue" \
    --output text \
    --region $REGION | cut -d'/' -f3 | cut -d'.' -f1)

echo "API ID: $API_ID"

# Get API Gateway configuration
echo "Getting API Gateway configuration..."
aws apigateway get-rest-api \
    --rest-api-id $API_ID \
    --region $REGION

# Get API Gateway resources
echo "Getting API Gateway resources..."
aws apigateway get-resources \
    --rest-api-id $API_ID \
    --region $REGION

# Get API Gateway authorizers
echo "Getting API Gateway authorizers..."
aws apigateway get-authorizers \
    --rest-api-id $API_ID \
    --region $REGION

# Get API Gateway stages
echo "Getting API Gateway stages..."
aws apigateway get-stages \
    --rest-api-id $API_ID \
    --region $REGION

echo "API Gateway configuration check completed!"