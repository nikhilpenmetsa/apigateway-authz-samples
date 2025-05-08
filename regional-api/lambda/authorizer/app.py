import json
import os
import time
import boto3
import re
import base64
import urllib.request
from jose import jwk, jwt
from jose.utils import base64url_decode

# Environment variables
USER_POOL_ID = os.environ['USER_POOL_ID']
APP_CLIENT_ID = os.environ['APP_CLIENT_ID']
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')

# Cache for JWT token verification
jwks_cache = {}
jwks_url = f'https://cognito-idp.{AWS_REGION}.amazonaws.com/{USER_POOL_ID}/.well-known/jwks.json'

def lambda_handler(event, context):
    """
    Lambda handler for custom authorization
    """
    print(f"DEBUG: Received event: {json.dumps(event)}")
    print(f"DEBUG: USER_POOL_ID: {USER_POOL_ID}")
    print(f"DEBUG: APP_CLIENT_ID: {APP_CLIENT_ID}")
    
    try:
        # Get the authorization token from the request
        token = get_token_from_event(event)
        if not token:
            print("DEBUG: No token found in request")
            return generate_policy('user', 'Deny', event['methodArn'], {'message': 'Unauthorized'})
        
        print(f"DEBUG: Token found: {token[:20]}...")
        
        # Verify and decode the JWT token
        claims = verify_token(token)
        if not claims:
            print("DEBUG: Token verification failed")
            return generate_policy('user', 'Deny', event['methodArn'], {'message': 'Invalid token'})
        
        print(f"DEBUG: Token verified successfully. Claims: {json.dumps(claims)}")
        
        # Extract user information from the claims
        user_id = claims.get('sub')
        username = claims.get('username', claims.get('cognito:username', user_id))
        
        print(f"DEBUG: User ID: {user_id}, Username: {username}")
        
        # Check if token is expired
        current_time = int(time.time())
        if current_time > claims.get('exp', 0):
            print(f"DEBUG: Token expired. Current time: {current_time}, Expiry: {claims.get('exp')}")
            return generate_policy('user', 'Deny', event['methodArn'], {'message': 'Token expired'})
        
        # Additional authorization logic can be added here
        # For example, checking user groups or custom attributes
        
        # Generate IAM policy for the user
        policy = generate_policy(username, 'Allow', event['methodArn'], {
            'user_id': user_id,
            'username': username
        })
        
        print(f"DEBUG: Generated policy: {json.dumps(policy)}")
        return policy
        
    except Exception as e:
        print(f"ERROR: Exception in lambda_handler: {str(e)}")
        import traceback
        print(f"ERROR: Traceback: {traceback.format_exc()}")
        return generate_policy('user', 'Deny', event['methodArn'], {'message': 'Authorization error'})

def get_token_from_event(event):
    """
    Extract the JWT token from the event
    For TOKEN authorizer type, the token is in authorizationToken
    For REQUEST authorizer type, the token is in the headers
    """
    # Check for TOKEN authorizer type
    if 'authorizationToken' in event:
        auth_token = event['authorizationToken']
        print(f"DEBUG: Found authorizationToken: {auth_token[:20]}...")
        
        # Check if it's a Bearer token
        match = re.match(r'Bearer\s+(.+)', auth_token)
        if match:
            token = match.group(1)
            print("DEBUG: Bearer token extracted from authorizationToken")
            return token
        
        print("DEBUG: Using authorizationToken value as token")
        return auth_token
    
    # Check for REQUEST authorizer type (headers)
    headers = event.get('headers', {})
    if headers:
        print(f"DEBUG: Headers: {json.dumps(headers)}")
        
        auth_header = headers.get('Authorization', headers.get('authorization'))
        if auth_header:
            print(f"DEBUG: Authorization header: {auth_header[:20]}...")
            
            # Check if it's a Bearer token
            match = re.match(r'Bearer\s+(.+)', auth_header)
            if match:
                token = match.group(1)
                print("DEBUG: Bearer token extracted from headers")
                return token
            
            print("DEBUG: Using header value as token")
            return auth_header
    
    print("DEBUG: No token found in event")
    return None

def get_jwks():
    """
    Get the JSON Web Key Set (JWKS) from Cognito
    """
    global jwks_cache
    
    # Check if we have a cached copy
    if jwks_cache and jwks_cache.get('expiry', 0) > time.time():
        print("DEBUG: Using cached JWKS")
        return jwks_cache.get('keys')
    
    # Fetch the JWKS from Cognito
    print(f"DEBUG: Fetching JWKS from {jwks_url}")
    try:
        with urllib.request.urlopen(jwks_url) as response:
            jwks = json.loads(response.read().decode('utf-8'))
        
        print(f"DEBUG: JWKS fetched successfully: {json.dumps(jwks)[:200]}...")
        
        # Cache the JWKS for 1 hour
        jwks_cache = {
            'keys': jwks['keys'],
            'expiry': time.time() + 3600
        }
        
        return jwks['keys']
    except Exception as e:
        print(f"ERROR: Failed to fetch JWKS: {str(e)}")
        raise

def verify_token(token):
    """
    Verify the JWT token using the JWKS from Cognito
    """
    # Get the key ID from the token header
    try:
        # Get the kid from the headers prior to verification
        headers = jwt.get_unverified_headers(token)
        print(f"DEBUG: Token headers: {json.dumps(headers)}")
        kid = headers['kid']
        print(f"DEBUG: Token kid: {kid}")
    except Exception as e:
        print(f"ERROR: Error getting unverified headers: {str(e)}")
        return None
    
    # Get the public keys
    try:
        keys = get_jwks()
        print(f"DEBUG: Got {len(keys)} keys from JWKS")
    except Exception as e:
        print(f"ERROR: Failed to get JWKS: {str(e)}")
        return None
        
    key_data = None
    
    # Find the key matching the key ID in the token
    for k in keys:
        if k['kid'] == kid:
            key_data = k
            print(f"DEBUG: Found matching key: {json.dumps(k)[:100]}...")
            break
    
    if not key_data:
        print("ERROR: Public key not found in jwks.json")
        return None
    
    # Verify the token
    try:
        # Construct the public key
        public_key = jwk.construct(key_data)
        print("DEBUG: Public key constructed")
        
        # Get the message and signature (encoded in base64)
        message, encoded_signature = token.rsplit('.', 1)
        print(f"DEBUG: Message: {message[:20]}..., Signature: {encoded_signature[:20]}...")
        
        # Decode the signature
        decoded_signature = base64url_decode(encoded_signature.encode('utf-8'))
        print("DEBUG: Signature decoded")
        
        # Verify the signature
        if not public_key.verify(message.encode('utf-8'), decoded_signature):
            print("ERROR: Signature verification failed")
            return None
        
        print("DEBUG: Signature verified successfully")
        
        # Since we passed the verification, we can now safely use the unverified claims
        claims = jwt.get_unverified_claims(token)
        print(f"DEBUG: Claims: {json.dumps(claims)}")
        
        # Additionally we can verify the token expiration
        if time.time() > claims['exp']:
            print(f"ERROR: Token is expired. Current time: {time.time()}, Expiry: {claims['exp']}")
            return None
        
        # And the Audience (use claims['client_id'] if verifying an access token)
        if 'aud' in claims:
            if claims['aud'] != APP_CLIENT_ID:
                print(f"ERROR: Token was not issued for this audience. Expected: {APP_CLIENT_ID}, Got: {claims['aud']}")
                return None
        elif 'client_id' in claims:
            if claims['client_id'] != APP_CLIENT_ID:
                print(f"ERROR: Token was not issued for this client. Expected: {APP_CLIENT_ID}, Got: {claims['client_id']}")
                return None
        else:
            print("WARNING: No audience or client_id claim found in token")
        
        return claims
    except Exception as e:
        print(f"ERROR: Token verification failed: {str(e)}")
        import traceback
        print(f"ERROR: Traceback: {traceback.format_exc()}")
        return None

def generate_policy(principal_id, effect, resource, context=None):
    """
    Generate an IAM policy document
    """
    policy = {
        'principalId': principal_id,
        'policyDocument': {
            'Version': '2012-10-17',
            'Statement': [
                {
                    'Action': 'execute-api:Invoke',
                    'Effect': effect,
                    'Resource': resource
                }
            ]
        }
    }
    
    # Add context if provided
    if context:
        policy['context'] = context
    
    return policy