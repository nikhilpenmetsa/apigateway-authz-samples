#!/bin/bash
set -e

# Configuration - Replace with your actual values
API_TYPE="regional"  # or "private"
REGION="us-east-1"
STAGE="dev"
USER_EMAIL="user@example.com"
USER_PASSWORD="YourSecurePassword123!"

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq first."
    exit 1
fi

# Get stack outputs
if [ "$API_TYPE" == "regional" ]; then
    STACK_NAME="apigw-authz-regional"
else
    STACK_NAME="apigw-authz-private"
fi

echo "Getting stack outputs..."
USER_POOL_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs[?OutputKey=='UserPoolId'].OutputValue" \
    --output text \
    --region $REGION)

USER_POOL_CLIENT_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs[?OutputKey=='UserPoolClientId'].OutputValue" \
    --output text \
    --region $REGION)

echo "User Pool ID: $USER_POOL_ID"
echo "User Pool Client ID: $USER_POOL_CLIENT_ID"

# Get authentication token
echo "Getting authentication token..."
AUTH_RESULT=$(aws cognito-idp admin-initiate-auth \
    --user-pool-id $USER_POOL_ID \
    --client-id $USER_POOL_CLIENT_ID \
    --auth-flow ADMIN_USER_PASSWORD_AUTH \
    --auth-parameters USERNAME=$USER_EMAIL,PASSWORD=$USER_PASSWORD \
    --region $REGION)

ID_TOKEN=$(echo $AUTH_RESULT | jq -r '.AuthenticationResult.IdToken')
echo "ID Token: ${ID_TOKEN:0:20}..."

# Decode the token
echo "Decoding token header..."
HEADER=$(echo $ID_TOKEN | cut -d. -f1 | base64 -d 2>/dev/null || echo $ID_TOKEN | cut -d. -f1 | base64 -di)
echo $HEADER | jq .

echo "Decoding token payload..."
PAYLOAD=$(echo $ID_TOKEN | cut -d. -f2 | base64 -d 2>/dev/null || echo $ID_TOKEN | cut -d. -f2 | base64 -di)
echo $PAYLOAD | jq .

echo "Token debugging completed!"