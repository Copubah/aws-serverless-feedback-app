import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('UserFeedback')

def lambda_handler(event, context):
    try:
        feedback_id = event['pathParameters']['id']
        
        table.delete_item(
            Key={'feedback_id': feedback_id}
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, GET, DELETE, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            },
            'body': json.dumps({
                'message': 'Feedback deleted successfully',
                'feedback_id': feedback_id
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': str(e)})
        }