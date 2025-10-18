import json
import pytest
import boto3
from moto import mock_dynamodb
from backend.create_feedback import lambda_handler as create_handler
from backend.get_feedback import lambda_handler as get_handler
from backend.delete_feedback import lambda_handler as delete_handler

@mock_dynamodb
class TestFeedbackAPI:
    
    def setup_method(self):
        """Setup test environment"""
        self.dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
        
        # Create test table
        self.table = self.dynamodb.create_table(
            TableName='UserFeedback',
            KeySchema=[
                {'AttributeName': 'feedback_id', 'KeyType': 'HASH'}
            ],
            AttributeDefinitions=[
                {'AttributeName': 'feedback_id', 'AttributeType': 'S'}
            ],
            BillingMode='PAY_PER_REQUEST'
        )
    
    def test_create_feedback_success(self):
        """Test successful feedback creation"""
        event = {
            'body': json.dumps({
                'name': 'Test User',
                'message': 'This is a test message'
            }),
            'headers': {},
            'requestContext': {
                'identity': {'sourceIp': '127.0.0.1'}
            }
        }
        
        response = create_handler(event, {})
        
        assert response['statusCode'] == 200
        body = json.loads(response['body'])
        assert body['message'] == 'Feedback created successfully'
        assert 'feedback_id' in body
    
    def test_create_feedback_validation_error(self):
        """Test validation error handling"""
        event = {
            'body': json.dumps({
                'name': 'A',  # Too short
                'message': 'Test'  # Too short
            }),
            'headers': {},
            'requestContext': {'identity': {'sourceIp': '127.0.0.1'}}
        }
        
        response = create_handler(event, {})
        
        assert response['statusCode'] == 400
        body = json.loads(response['body'])
        assert 'error' in body
    
    def test_create_feedback_xss_prevention(self):
        """Test XSS prevention"""
        event = {
            'body': json.dumps({
                'name': 'Test User',
                'message': '<script>alert("xss")</script>Test message'
            }),
            'headers': {},
            'requestContext': {'identity': {'sourceIp': '127.0.0.1'}}
        }
        
        response = create_handler(event, {})
        
        assert response['statusCode'] == 400
        body = json.loads(response['body'])
        assert 'Invalid characters detected' in body['error']
    
    def test_get_feedback_empty(self):
        """Test getting feedback when none exists"""
        event = {'headers': {}}
        
        response = get_handler(event, {})
        
        assert response['statusCode'] == 200
        body = json.loads(response['body'])
        assert body['feedback'] == []
        assert body['count'] == 0
    
    def test_delete_feedback_not_found(self):
        """Test deleting non-existent feedback"""
        event = {
            'pathParameters': {'id': 'non-existent-id'},
            'headers': {}
        }
        
        response = delete_handler(event, {})
        
        # Should still return success (idempotent)
        assert response['statusCode'] == 200

if __name__ == '__main__':
    pytest.main([__file__])