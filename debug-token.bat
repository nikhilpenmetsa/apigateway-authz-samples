@echo off
setlocal enabledelayedexpansion

REM Configuration - Replace with your actual values
set API_TYPE=regional
set REGION=us-east-1
set STAGE=dev
set USER_EMAIL=user@example.com
set USER_PASSWORD=YourSecurePassword123!

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

echo User Pool ID: !USER_POOL_ID!
echo User Pool Client ID: !USER_POOL_CLIENT_ID!

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

REM Decode the token using PowerShell
echo Decoding token header...
powershell -Command "$header = '!ID_TOKEN!'.Split('.')[0]; $headerJson = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($header.Replace('-', '+').Replace('_', '/').PadRight($header.Length + (4 - $header.Length %% 4) %% 4, '='))); $headerJson | ConvertFrom-Json | ConvertTo-Json"

echo Decoding token payload...
powershell -Command "$payload = '!ID_TOKEN!'.Split('.')[1]; $payloadJson = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($payload.Replace('-', '+').Replace('_', '/').PadRight($payload.Length + (4 - $payload.Length %% 4) %% 4, '='))); $payloadJson | ConvertFrom-Json | ConvertTo-Json"

echo Token debugging completed!

REM Clean up temporary files
del %AUTH_RESULT_FILE% 2>nul