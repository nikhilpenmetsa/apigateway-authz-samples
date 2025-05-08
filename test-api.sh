#!/bin/bash
set -e

# Configuration - Replace with your actual values
API_TYPE="regional"  # or "private"
REGION="us-east-1"
STAGE="dev"
USER_EMAIL="user@example.com"
USER_PASSWORD="YourSecurePassword123!"
CUSTOMER_ID="test-customer-1"

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq first."
    echo "On Ubuntu/Debian: sudo apt-get install jq"
    echo "On CentOS/RHEL: sudo yum install jq"
    echo "On macOS: brew install jq"
    echo "On Windows: Install from https://stedolan.github.io/jq/download/"
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

API_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs[?OutputKey=='ApiEndpoint'].OutputValue" \
    --output text \
    --region $REGION)

echo "User Pool ID: $USER_POOL_ID"
echo "User Pool Client ID: $USER_POOL_CLIENT_ID"
echo "API Endpoint: $API_ENDPOINT"

# Create a test user if it doesn't exist
echo "Creating test user..."
aws cognito-idp admin-create-user \
    --user-pool-id $USER_POOL_ID \
    --username $USER_EMAIL \
    --temporary-password "Temp123!" \
    --user-attributes Name=email,Value=$USER_EMAIL Name=email_verified,Value=true \
    --region $REGION || echo "User may already exist"

# Set permanent password
echo "Setting permanent password..."
aws cognito-idp admin-set-user-password \
    --user-pool-id $USER_POOL_ID \
    --username $USER_EMAIL \
    --password $USER_PASSWORD \
    --permanent \
    --region $REGION

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

#Test PUT request to create/update customer data
echo "Testing PUT request to create/update customer data..."
curl -X PUT \
    "$API_ENDPOINT/customers/$CUSTOMER_ID" \
    -H "Authorization: Bearer $ID_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"name": "John Doe", "phoneNumber": "123-456-7890", "email": "john.doe@example.com"}' \
    -v

echo ""
echo "Waiting 2 seconds..."
sleep 2

# Test GET request to retrieve customer data
echo "Testing GET request to retrieve customer data..."
curl -X GET \
    "$API_ENDPOINT/customers/$CUSTOMER_ID" \
    -H "Authorization: Bearer $ID_TOKEN" \
    -v

echo ""
echo "API testing completed!"