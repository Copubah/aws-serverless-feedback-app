import json
import boto3
import uuid
from datetime import datetime
try:
    from .utils import validate_feedback_input, sanitize_string, create_response, log_event
except ImportError:
    from utils import validate_feedback_input, sanitize_string, create_response, log_event

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('UserFeedback')

def lambda_handler(event, context):
    correlation_id = event.get('headers', {}).get('X-Correlation-ID', str(uuid.uuid4()))
    
    try:
        # Parse and validate input
        body = json.loads(event.get('body', '{}'))
        
        validation_error = validate_feedback_input(body)
        if validation_error:
            log_event('validation_error', {'error': validation_error}, correlation_id)
            return create_response(400, {'error': validation_error}, correlation_id)
        
        # Sanitize inputs
        name = sanitize_string(body['name'])
        message = sanitize_string(body['message'])
        
        feedback_item = {
            'feedback_id': str(uuid.uuid4()),
            'name': name,
            'message': message,
            'timestamp': datetime.utcnow().isoformat(),
            'created_by_ip': event.get('requestContext', {}).get('identity', {}).get('sourceIp', 'unknown')
        }
        
        table.put_item(Item=feedback_item)
        
        log_event('feedback_created', {
            'feedback_id': feedback_item['feedback_id'],
            'name_length': len(name),
            'message_length': len(message)
        }, correlation_id)
        
        return create_response(200, {
            'message': 'Feedback created successfully',
            'feedback_id': feedback_item['feedback_id']
        }, correlation_id)
        
    except json.JSONDecodeError:
        log_event('json_decode_error', {'body': event.get('body', '')}, correlation_id)
        return create_response(400, {'error': 'Invalid JSON format'}, correlation_id)
    except Exception as e:
        log_event('unexpected_error', {'error': str(e)}, correlation_id)
        return create_response(500, {'error': 'Internal server error'}, correlation_id)