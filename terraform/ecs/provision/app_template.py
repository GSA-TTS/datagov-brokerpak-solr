import boto3
import json
print('Loading function')

def handler(event, context):
    print("Full event: " + json.dumps(event, indent=2))
    # Parse Message
    message = event['Records'][0]['Sns']['Message']
    print("From SNS: " + message)
    message_json = json.loads(message)

    # Parse Alarm State
    state = message_json['NewStateValue']

    # Parse/Restart ECS Service
    service_dimensions = identifyCluster(message_json)
    if state == 'ALARM':
        restartSolrECS(message_json, service_dimensions['ClusterName'], service_dimensions['ServiceName'])
        notifySlack(message_json, service_dimensions['ClusterName'], service_dimensions['ServiceName'])
    elif state == 'OK':
        notifySlack(message_json, service_dimensions['ClusterName'], service_dimensions['ServiceName'])

    return message


def identifyCluster(event_info):
    service_dimensions = {}
    for dim in event_info['Trigger']['Dimensions']:
        service_dimensions[dim['name']] = dim['value']
    return service_dimensions


def restartSolrECS(message_json, cluster_name, service_name):
    '''
    Reference: https://github.com/s7anley/aws-ecs-service-stop-lambda/blob/master/main.py
    '''
    service_region = message_json['AlarmArn'].split(':')[3]

    client = boto3.client("ecs", region_name=service_region)
    response = client.list_tasks(
        cluster=cluster_name,
        family="%s-service" % (service_name))
    tasks = response.get('taskArns', [])
    print("Service is running {0} underlying tasks".format(len(tasks)))

    for task in tasks:
        print("Stopping tasks {0}".format(tasks))
        client.stop_task(cluster=cluster_name, task=task)

    print("Completed service restart")


def notifySlack(event_info, cluster, service):
    from slack_sdk.webhook import WebhookClient
    webhook = WebhookClient("<slack-notification-url>")

    important_data = ["Alarm Name", "New State Value", "New State Reason", "State Change Time"]
    emoji = "😨" if event_info["NewStateValue"] == "ALARM" else "😐"

    response = webhook.send(blocks=[
        {
            "type": "divider"
        },
        {
            "type": "context",
            "elements": [
                {
                    "type": "image",
                    "image_url": "https://s3-us-gov-west-1.amazonaws.com/cg-0817d6e3-93c4-4de8-8b32-da6919464e61/solr.png",
                    "alt_text": "Solr Icon"
                },
                {
                    "type": "mrkdwn",
                    "text": ":::ALERT::: *%s/%s* has experienced an event. " % (service['ClusterName'], service['ServiceName']) + emoji
                }
            ]
        },
        {
            "type": "divider"
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "".join(["*%s*:\n%s\n\n" % (key, event_info[key.replace(" ", "")]) for key in important_data])
            },
            "accessory": {
                "type": "image",
		"image_url": "https://s3-us-gov-west-1.amazonaws.com/cg-0817d6e3-93c4-4de8-8b32-da6919464e61/solr.png",
                "alt_text": "Solr Alert"
            }
        },
        {
            "type": "divider"
        }
    ])

    assert response.status_code == 200
    assert response.body == "ok"
