@echo off
setlocal enabledelayedexpansion

REM Configuration - Replace with your actual values
set API_TYPE=regional
set REGION=us-east-1
set STAGE=dev
set USER_EMAIL=user@example.com
set USER_PASSWORD=YourSecurePassword123!
set CUSTOMER_ID=test-customer-1

REM Get stack outputs
if "%API_TYPE%"=="regional" (
    set STACK_NAME=apigw-authz-regional
) else (
    set STACK_NAME=apigw-authz-private
)

echo Getting stack outputs...
for /f "tokens=*" %%a in ('aws cloudformation describe-stacks --stack-name !STACK_NAME! --query "Stacks[0].Outputs[?OutputKey==''UserPoolId''].OutputValue" --output text --region %REGION%') do (
    set USER_POOL_ID=%%a
)

for /f "tokens=*" %%a in ('aws cloudformation describe-stacks --stack-name !STACK_NAME! --query "Stacks[0].Outputs[?OutputKey==''UserPoolClientId''].OutputValue" --output text --region %REGION%') do (
    set USER_POOL_CLIENT_ID=%%a
)

for /f "tokens=*" %%a in ('aws cloudformation describe-stacks --stack-name !STACK_NAME! --query "Stacks[0].Outputs[?OutputKey==''ApiEndpoint''].OutputValue" --output text --region %REGION%') do (
    set API_ENDPOINT=%%a
)

echo User Pool ID: !USER_POOL_ID!
echo User Pool Client ID: !USER_POOL_CLIENT_ID!
echo API Endpoint: !API_ENDPOINT!

REM Create a test user if it doesn't exist
echo Creating test user...
aws cognito-idp admin-create-user --user-pool-id !USER_POOL_ID! --username %USER_EMAIL% --temporary-password "Temp123!" --user-attributes Name=email,Value=%USER_EMAIL% Name=email_verified,Value=true --region %REGION% 2>nul || echo User may already exist

REM Set permanent password
echo Setting permanent password...
aws cognito-idp admin-set-user-password --user-pool-id !USER_POOL_ID! --username %USER_EMAIL% --password %USER_PASSWORD% --permanent --region %REGION%

REM Get authentication token
echo Getting authentication token...
set AUTH_RESULT_FILE=%TEMP%\auth_result.json
aws cognito-idp admin-initiate-auth --user-pool-id !USER_POOL_ID! --client-id !USER_POOL_CLIENT_ID! --auth-flow ADMIN_USER_PASSWORD_AUTH --auth-parameters USERNAME=%USER_EMAIL%,PASSWORD=%USER_PASSWORD% --region %REGION% > %AUTH_RESULT_FILE%

REM Extract ID token using PowerShell
echo Extracting ID token...
for /f "tokens=*" %%a in ('powershell -Command "Get-Content %AUTH_RESULT_FILE% | ConvertFrom-Json | Select-Object -ExpandProperty AuthenticationResult | Select-Object -ExpandProperty IdToken"') do (
    set ID_TOKEN=%%a
)

echo ID Token: !ID_TOKEN:~0,20!...

REM Test PUT request to create/update customer data
echo Testing PUT request to create/update customer data...
curl -X PUT ^
    "!API_ENDPOINT!/customers/%CUSTOMER_ID%" ^
    -H "Authorization: Bearer !ID_TOKEN!" ^
    -H "Content-Type: application/json" ^
    -d "{\"name\": \"John Doe\", \"phoneNumber\": \"123-456-7890\", \"email\": \"john.doe@example.com\"}" ^
    -v

echo.
echo Waiting 2 seconds...
timeout /t 2 /nobreak > nul

REM Test GET request to retrieve customer data
echo Testing GET request to retrieve customer data...
curl -X GET ^
    "!API_ENDPOINT!/customers/%CUSTOMER_ID%" ^
    -H "Authorization: Bearer !ID_TOKEN!" ^
    -v

echo.
echo API testing completed!

REM Clean up temporary files
del %AUTH_RESULT_FILE% 2>nul