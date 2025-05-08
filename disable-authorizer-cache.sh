#!/bin/bash
set -e

# Configuration
REGION="us-east-1"
STACK_NAME="apigw-authz-regional"

# Get the API ID for the original API
echo "Getting API ID for the original API..."
API_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].Resources[?LogicalResourceId=='CustomerAPI'].PhysicalResourceId" \
    --output text \
    --region $REGION)

if [ -z "$API_ID" ]; then
    echo "Getting API ID using alternative method..."
    API_ID=$(aws apigateway get-rest-apis \
        --query "items[?name=='customer-api-dev'].id" \
        --output text \
        --region $REGION)
fi

echo "API ID: $API_ID"

# Get the authorizer ID
echo "Getting authorizer ID..."
AUTHORIZER_ID=$(aws apigateway get-authorizers \
    --rest-api-id $API_ID \
    --query "items[?name=='CustomAuthorizer'].id" \
    --output text \
    --region $REGION)

echo "Authorizer ID: $AUTHORIZER_ID"

# Check current caching value
echo "Checking current authorizer caching value..."
CURRENT_TTL=$(aws apigateway get-authorizer \
    --rest-api-id $API_ID \
    --authorizer-id $AUTHORIZER_ID \
    --query "authorizerResultTtlInSeconds" \
    --output text \
    --region $REGION)

echo "Current authorizer cache TTL: $CURRENT_TTL seconds"

# Update the authorizer to disable caching
echo "Updating authorizer to disable caching..."
aws apigateway update-authorizer \
    --rest-api-id $API_ID \
    --authorizer-id $AUTHORIZER_ID \
    --patch-operations op=replace,path=/authorizerResultTtlInSeconds,value=0 \
    --region $REGION

# Verify the update
echo "Verifying the update..."
NEW_TTL=$(aws apigateway get-authorizer \
    --rest-api-id $API_ID \
    --authorizer-id $AUTHORIZER_ID \
    --query "authorizerResultTtlInSeconds" \
    --output text \
    --region $REGION)

echo "New authorizer cache TTL: $NEW_TTL seconds"

# Deploy the API to apply changes
echo "Deploying the API to apply changes..."
aws apigateway create-deployment \
    --rest-api-id $API_ID \
    --stage-name dev \
    --region $REGION

echo "Authorizer cache disabled successfully!"