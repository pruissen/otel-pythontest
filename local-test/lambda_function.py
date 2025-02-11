import json
import requests


# lambda function
def lambda_handler(event, context):
    requests.get("https://www.google.com")
    requests.get("http://httpbin.org/")
    return {"statusCode": 200, "body": json.dumps({"message":"Success execution"})}