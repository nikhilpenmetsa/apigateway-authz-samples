@echo off
setlocal enabledelayedexpansion

REM Configuration
set STACK_NAME=apigw-authz-regional
set STAGE=dev
set REGION=us-east-1
set S3_BUCKET=apigw-authz-deployment-bucket

REM Create S3 bucket if it doesn't exist
echo Checking if S3 bucket exists...
aws s3 ls "s3://%S3_BUCKET%" 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Creating S3 bucket: %S3_BUCKET%
    aws s3 mb "s3://%S3_BUCKET%" --region %REGION%
)

REM Change to the regional API directory
cd "%~dp0\regional-api"

REM Install dependencies for Lambda functions
echo Installing dependencies for Lambda functions...

REM Customer data function
echo Installing dependencies for customer data function...
cd lambda\customer_data
pip install -r requirements.txt -t .
cd ..\..

REM Authorizer function
echo Installing dependencies for authorizer function...
cd lambda\authorizer
pip install -r requirements.txt -t .
cd ..\..

REM Package the CloudFormation template
echo Packaging CloudFormation template...
aws cloudformation package ^
    --template-file template.yaml ^
    --s3-bucket %S3_BUCKET% ^
    --s3-prefix %STACK_NAME% ^
    --output-template-file packaged.yaml ^
    --region %REGION%

REM Deploy the CloudFormation stack
echo Deploying CloudFormation stack: %STACK_NAME%...
aws cloudformation deploy ^
    --template-file packaged.yaml ^
    --stack-name %STACK_NAME% ^
    --parameter-overrides Stage=%STAGE% ^
    --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND ^
    --region %REGION%

REM Get stack outputs
echo Getting stack outputs...
aws cloudformation describe-stacks ^
    --stack-name %STACK_NAME% ^
    --query "Stacks[0].Outputs" ^
    --output table ^
    --region %REGION%

echo Deployment completed successfully!