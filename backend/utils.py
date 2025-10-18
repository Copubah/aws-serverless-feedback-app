import json
import logging
import re
from datetime import datetime
from typing import Dict, Any, Optional

# Configure structured logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def validate_feedback_input(data: Dict[str, Any]) -> Optional[str]:
    """Validate feedback input data"""
    if not isinstance(data, dict):
        return "Invalid data format"
    
    name = data.get('name', '').strip()
    message = data.get('message', '').strip()
    
    if not name or len(name) < 2:
        return "Name must be at least 2 characters long"
    
    if len(name) > 100:
        return "Name must be less than 100 characters"
    
    if not message or len(message) < 5:
        return "Message must be at least 5 characters long"
    
    if len(message) > 1000:
        return "Message must be less than 1000 characters"
    
    # Basic XSS prevention
    if re.search(r'<script|javascript:|on\w+\s*=', name + message, re.IGNORECASE):
        return "Invalid characters detected"
    
    return None

def sanitize_string(text: str) -> str:
    """Sanitize string input"""
    if not isinstance(text, str):
        return ""
    
    # Remove potential XSS patterns
    text = re.sub(r'<script.*?</script>', '', text, flags=re.IGNORECASE | re.DOTALL)
    text = re.sub(r'javascript:', '', text, flags=re.IGNORECASE)
    text = re.sub(r'on\w+\s*=', '', text, flags=re.IGNORECASE)
    
    return text.strip()

def create_response(status_code: int, body: Dict[str, Any], correlation_id: str = None) -> Dict[str, Any]:
    """Create standardized API response"""
    response = {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, GET, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, X-Correlation-ID'
        },
        'body': json.dumps(body)
    }
    
    if correlation_id:
        response['headers']['X-Correlation-ID'] = correlation_id
    
    return response

def log_event(event_type: str, details: Dict[str, Any], correlation_id: str = None):
    """Structured logging"""
    log_data = {
        'event_type': event_type,
        'timestamp': str(datetime.utcnow()),
        'details': details
    }
    
    if correlation_id:
        log_data['correlation_id'] = correlation_id
    
    logger.info(json.dumps(log_data))