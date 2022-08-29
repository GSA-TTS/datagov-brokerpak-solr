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
    if state == 'ALARM':
        restartSolrECS(message_json)
    elif state == 'OK':
        pass

    return message

def restartSolrECS(message_json):
    '''
    Reference: https://github.com/s7anley/aws-ecs-service-stop-lambda/blob/master/main.py
    '''
    service_dimensions = {}
    for dim in message_json['Trigger']['Dimensions']:
        service_dimensions[dim['name']] = dim['value']
    service_region = message_json['AlarmArn'].split(':')[3]

    client = boto3.client("ecs", region_name=service_region)
    response = client.list_tasks(
        cluster=service_dimensions['ClusterName'],
        family="%s-service" % (service_dimensions['ServiceName']))
    tasks = response.get('taskArns', [])
    print("Service is running {0} underlying tasks".format(len(tasks)))

    for task in tasks:
        print("Stopping tasks {0}".format(tasks))
        client.stop_task(cluster=cluster, task=task)

    print("Completed service restart")
