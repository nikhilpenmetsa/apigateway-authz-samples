@echo off
setlocal enabledelayedexpansion

REM Configuration - Replace with your actual values
set API_TYPE=regional
set REGION=us-east-1
set STAGE=dev

REM Get stack outputs
if "%API_TYPE%"=="regional" (
    set STACK_NAME=apigw-authz-regional
) else (
    set STACK_NAME=apigw-authz-private
)

echo Getting stack outputs...
for /f "tokens=*" %%a in ('aws cloudformation describe-stacks --stack-name !STACK_NAME! --query "Stacks[0].Outputs[?OutputKey==''ApiEndpoint''].OutputValue" --output text --region %REGION%') do (
    set API_ENDPOINT=%%a
)

REM Extract API ID from endpoint URL
for /f "tokens=1,2,3 delims=." %%a in ("!API_ENDPOINT!") do (
    set API_ID=%%a
    set API_ID=!API_ID:~8!
)

echo API ID: !API_ID!

REM Get API Gateway configuration
echo Getting API Gateway configuration...
aws apigateway get-rest-api --rest-api-id !API_ID! --region %REGION%

REM Get API Gateway resources
echo Getting API Gateway resources...
aws apigateway get-resources --rest-api-id !API_ID! --region %REGION%

REM Get API Gateway authorizers
echo Getting API Gateway authorizers...
aws apigateway get-authorizers --rest-api-id !API_ID! --region %REGION%

REM Get API Gateway stages
echo Getting API Gateway stages...
aws apigateway get-stages --rest-api-id !API_ID! --region %REGION%

echo API Gateway configuration check completed!