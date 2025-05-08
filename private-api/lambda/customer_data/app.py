import json
import os
import boto3
import uuid
from datetime import datetime

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    """
    Lambda handler for customer data operations
    """
    try:
        # Extract HTTP method and path parameters
        http_method = event['httpMethod']
        path_parameters = event.get('pathParameters', {})
        customer_id = path_parameters.get('customerId') if path_parameters else None
        
        # Handle GET request - retrieve customer data
        if http_method == 'GET':
            if not customer_id:
                return build_response(400, {'message': 'Missing customerId parameter'})
            
            response = table.get_item(Key={'customerId': customer_id})
            item = response.get('Item')
            
            if not item:
                return build_response(404, {'message': 'Customer not found'})
            
            return build_response(200, item)
        
        # Handle PUT request - create or update customer data
        elif http_method == 'PUT':
            # Parse request body
            body = json.loads(event['body']) if event.get('body') else {}
            
            if not customer_id:
                # Generate a new customer ID if not provided
                customer_id = str(uuid.uuid4())
            
            # Validate required fields
            if 'name' not in body or 'phoneNumber' not in body:
                return build_response(400, {'message': 'Missing required fields: name and phoneNumber'})
            
            # Create item to store in DynamoDB
            item = {
                'customerId': customer_id,
                'name': body['name'],
                'phoneNumber': body['phoneNumber'],
                'updatedAt': datetime.utcnow().isoformat(),
            }
            
            # Add optional fields if present
            if 'email' in body:
                item['email'] = body['email']
            if 'address' in body:
                item['address'] = body['address']
            
            # Store in DynamoDB
            table.put_item(Item=item)
            
            return build_response(200, {
                'message': 'Customer data saved successfully',
                'customerId': customer_id
            })
        
        # Handle unsupported methods
        else:
            return build_response(405, {'message': 'Method not allowed'})
            
    except Exception as e:
        print(f"Error: {str(e)}")
        return build_response(500, {'message': 'Internal server error'})

def build_response(status_code, body):
    """
    Helper function to build the response object
    """
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET,PUT,OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization'
        },
        'body': json.dumps(body)
    }