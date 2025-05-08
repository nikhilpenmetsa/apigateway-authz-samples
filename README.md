# AWS API Gateway Authorization Demo

This project demonstrates AWS API Gateway's authorization capabilities using two different setups:

1. **Regional API Gateway** with Lambda integration, DynamoDB, and Cognito User Pool for authentication
2. **Private API Gateway** in a VPC with similar functionality

## Project Structure

```
apigw-authz/
├── regional-api/
│   ├── template.yaml                # CloudFormation template for regional API
│   └── lambda/
│       ├── customer_data/           # Lambda function for customer data operations
│       │   ├── app.py
│       │   └── requirements.txt
│       └── authorizer/              # Lambda function for custom authorization
│           ├── app.py
│           └── requirements.txt
├── private-api/
│   ├── template.yaml                # CloudFormation template for private API
│   └── lambda/
│       ├── customer_data/           # Lambda function for customer data operations
│       │   ├── app.py
│       │   └── requirements.txt
│       └── authorizer/              # Lambda function for custom authorization
│           ├── app.py
│           └── requirements.txt
├── deploy-regional.sh               # Deployment script for regional API (Linux/macOS)
├── deploy-regional.bat              # Deployment script for regional API (Windows)
├── deploy-private.sh                # Deployment script for private API (Linux/macOS)
├── deploy-private.bat               # Deployment script for private API (Windows)
├── test-api.sh                      # API testing script (Linux/macOS)
├── test-api.bat                     # API testing script (Windows)
├── debug-token.sh                   # Token debugging script (Linux/macOS)
├── debug-token.bat                  # Token debugging script (Windows)
├── check-api-config.sh              # API Gateway configuration check script (Linux/macOS)
├── check-api-config.bat             # API Gateway configuration check script (Windows)
└── README.md                        # This file
```

## Regional API Gateway Setup

The regional API Gateway setup includes:

- API Gateway with regional endpoint
- Lambda function for customer data operations (GET/PUT)
- DynamoDB table for storing customer data
- Cognito User Pool for authentication
- Custom Lambda authorizer for validating JWT tokens

### Deployment

#### On Linux/macOS:

1. Update the configuration in `deploy-regional.sh` with your preferred AWS region and S3 bucket name.
2. Make the script executable:
   ```
   chmod +x deploy-regional.sh
   ```
3. Run the deployment script:
   ```
   ./deploy-regional.sh
   ```

#### On Windows:

1. Update the configuration in `deploy-regional.bat` with your preferred AWS region and S3 bucket name.
2. Run the deployment script:
   ```
   deploy-regional.bat
   ```

## Private API Gateway Setup

The private API Gateway setup includes:

- API Gateway with private endpoint in a VPC
- VPC Endpoint for API Gateway
- Lambda functions in the VPC
- DynamoDB table for storing customer data
- Cognito User Pool for authentication
- Custom Lambda authorizer for validating JWT tokens

### Deployment

#### On Linux/macOS:

1. Update the configuration in `deploy-private.sh` with your:
   - Preferred AWS region
   - S3 bucket name
   - VPC ID
   - Subnet IDs
   - Security Group IDs
2. Make the script executable:
   ```
   chmod +x deploy-private.sh
   ```
3. Run the deployment script:
   ```
   ./deploy-private.sh
   ```

#### On Windows:

1. Update the configuration in `deploy-private.bat` with your:
   - Preferred AWS region
   - S3 bucket name
   - VPC ID
   - Subnet IDs
   - Security Group IDs
2. Run the deployment script:
   ```
   deploy-private.bat
   ```

## Testing the APIs

After deployment, you can test the APIs using the provided test scripts or manually.

### Using the Test Scripts

#### On Linux/macOS:

1. Update the configuration in `test-api.sh` with your:
   - API type (regional or private)
   - AWS region
   - User email and password
   - Customer ID for testing

2. Make the script executable:
   ```
   chmod +x test-api.sh
   ```

3. Run the test script:
   ```
   ./test-api.sh
   ```

#### On Windows:

1. Update the configuration in `test-api.bat` with your:
   - API type (regional or private)
   - AWS region
   - User email and password
   - Customer ID for testing

2. Run the test script:
   ```
   test-api.bat
   ```

### Manual Testing

1. Create a user in the Cognito User Pool:
   ```
   aws cognito-idp admin-create-user \
     --user-pool-id <UserPoolId> \
     --username <email> \
     --temporary-password <temp-password> \
     --user-attributes Name=email,Value=<email> Name=email_verified,Value=true
   ```

2. Set a permanent password:
   ```
   aws cognito-idp admin-set-user-password \
     --user-pool-id <UserPoolId> \
     --username <email> \
     --password <password> \
     --permanent
   ```

3. Get an authentication token:
   ```
   aws cognito-idp admin-initiate-auth \
     --user-pool-id <UserPoolId> \
     --client-id <UserPoolClientId> \
     --auth-flow ADMIN_USER_PASSWORD_AUTH \
     --auth-parameters USERNAME=<email>,PASSWORD=<password>
   ```

4. Use the token to make API requests:
   ```
   # Create/update customer data
   curl -X PUT \
     https://<api-id>.execute-api.<region>.amazonaws.com/<stage>/customers/<customer-id> \
     -H "Authorization: Bearer <IdToken>" \
     -H "Content-Type: application/json" \
     -d '{"name": "John Doe", "phoneNumber": "123-456-7890"}'

   # Get customer data
   curl -X GET \
     https://<api-id>.execute-api.<region>.amazonaws.com/<stage>/customers/<customer-id> \
     -H "Authorization: Bearer <IdToken>"
   ```

## Debugging Tools

This project includes several debugging tools to help troubleshoot issues:

### Token Debugging

Use the token debugging scripts to decode and inspect Cognito tokens:

- `debug-token.sh` (Linux/macOS)
- `debug-token.bat` (Windows)

These scripts will:
1. Get a token from Cognito
2. Decode the token header and payload
3. Display the token contents

### API Gateway Configuration Check

Use the API Gateway configuration check scripts to verify the API Gateway setup:

- `check-api-config.sh` (Linux/macOS)
- `check-api-config.bat` (Windows)

These scripts will:
1. Get the API ID from the stack outputs
2. Retrieve the API Gateway configuration
3. List the resources, authorizers, and stages

## Troubleshooting

### Common Issues

1. **Lambda Dependency Issues**
   
   If you encounter errors related to Python dependencies in Lambda functions, make sure you're using compatible versions. The authorizer Lambda uses `python-jose` instead of `PyJWT` and `cryptography` to avoid compatibility issues with the Lambda runtime.

2. **Authentication Errors**
   
   If you get authentication errors when testing the API, check that:
   - The Cognito User Pool Client has the `ADMIN_USER_PASSWORD_AUTH` flow enabled
   - You're using the correct User Pool ID and Client ID
   - The token hasn't expired
   - The token is being passed correctly in the Authorization header with the "Bearer" prefix

3. **API Gateway Authorizer Configuration**

   The API Gateway authorizer can be configured as either a TOKEN or REQUEST type:
   - TOKEN type: The token is passed in the `authorizationToken` field of the Lambda event
   - REQUEST type: The token is passed in the `headers` field of the Lambda event
   
   Our authorizer Lambda is configured to handle both types.

4. **VPC Configuration for Private API**
   
   For the private API, ensure that:
   - The VPC has DNS resolution and DNS hostnames enabled
   - The security groups allow traffic on port 443
   - The Lambda functions have proper network access to DynamoDB and Cognito

## Security Considerations

- The private API Gateway is only accessible from within the VPC or through VPN/Direct Connect
- All API endpoints are protected by Cognito authentication
- Custom authorizer validates JWT tokens and can implement additional authorization logic
- DynamoDB tables use server-side encryption
- Lambda functions run with minimal IAM permissions

## Cleanup

To delete the CloudFormation stacks and associated resources:

```
aws cloudformation delete-stack --stack-name apigw-authz-regional
aws cloudformation delete-stack --stack-name apigw-authz-private
```