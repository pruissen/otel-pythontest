#!/bin/env python
import logging
import requests

# Set up basic logging
logging.basicConfig(
    level=logging.DEBUG,  # Set the logging level to DEBUG
    format="%(asctime)s - %(levelname)s - %(message)s"  # Add timestamp and log level in log messages
)
logger = logging.getLogger()

def lambda_handler(event, context):
    url = "https://www.google.com"

    # Log that the request is being made
    logger.info(f"Making a request to {url}")

    try:
        # Make the HTTP GET request
        response = requests.get(url)
        response.raise_for_status()  # Raise an error for HTTP errors
        
        # Dump the response content as JSON
        logger.info(f"Response received successfully: {response.status_code}")
        
        return {
            "statusCode": str(response.status_code),
            "body": "Success"
        }
    except requests.exceptions.RequestException as e:
        logger.error(f"An error occurred: {e}")
        return {
            "statusCode": str({response.status_code}),
            "body": "Error occurred"
        }

if __name__ == "__main__":
    lambda_handler(None, None)