from __future__ import print_function
import urllib3
import json
import boto3
import time
import os
from botocore.vendored import requests

SUCCESS = "SUCCESS"
FAILED = "FAILED"

http = urllib3.PoolManager()

def send(event, context, responseStatus, responseData, physicalResourceId=None, noEcho=False, reason=None):

    responseUrl = event['ResponseURL']
    print(responseUrl)

    responseBody = {
        'Status' : responseStatus,
        'Reason' : reason or "See the details in CloudWatch Log Stream: {}".format(context.log_stream_name),
        'PhysicalResourceId' : physicalResourceId or context.log_stream_name,
        'StackId' : event['StackId'],
        'RequestId' : event['RequestId'],
        'LogicalResourceId' : event['LogicalResourceId'],
        'NoEcho' : noEcho,
        'Data' : responseData
    }

    json_responseBody = json.dumps(responseBody)

    print("Response body:")
    print(json_responseBody)

    headers = {
        'content-type' : '',
        'content-length' : str(len(json_responseBody))
    }

    try:
        response = http.request('PUT', responseUrl, headers=headers, body=json_responseBody)
        print("Status code:", response.status)


    except Exception as e:

        print("send(..) failed executing http.request(..):", e)

def lambda_handler(event, context):
  print(json.dumps(event))
  if event["RequestType"] == "Create":
      print("RequestType %s" % event["RequestType"])
      
      function_name = os.environ['lambda_arn']
      s3_bucket = os.environ['s3_bucket']
      
      response = boto3.client('lambda').add_permission(
          FunctionName=function_name,
          StatementId='S3callingLambdaForSocialMedia',
          Action='lambda:InvokeFunction',
          Principal='s3.amazonaws.com',
          SourceArn='arn:aws:s3:::' + s3_bucket,
          SourceAccount=os.environ['account_number']
      )

      response = boto3.client('s3').put_bucket_notification_configuration(
                          Bucket=s3_bucket,
                          NotificationConfiguration={
                                      'LambdaFunctionConfigurations': [
                                          {
                                              'Id': 'TriggerRawProcessing',
                                              'LambdaFunctionArn': function_name,
                                              'Events': [
                                                  's3:ObjectCreated:*'
                                              ],
                                              'Filter': {
                                                  'Key': {
                                                      'FilterRules': [
                                                          {
                                                              'Name': 'prefix',
                                                              'Value': 'raw/'
                                                          },
                                                      ]
                                                  }
                                              }
                                          },
                                      ]
                                  }
                              )
  else:
      print("RequestType %s, nothing to do" % event["RequestType"])

  send(event, context, SUCCESS, { "Outcome": "SUCCESS" });
