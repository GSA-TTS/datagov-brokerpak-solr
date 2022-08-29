import boto3
import json
print('Loading function')

def handler(event, context):
    print("Full event: " + json.dumps(event, indent=2))
    # Parse Message
    message = event['Records'][0]['Sns']['Message']
    print("From SNS: " + message)
    message_json = json.loads(message)

    # Parse/Restart ECS Service
    service_dimensions = {}
    for dim in message_json['Trigger']['Dimensions']:
        service_dimensions[dim['name']] = dim['value']
    service_region = message_json['AlarmArn'].split(':')[3]
    restartSolrECS(
        service_dimensions['ClusterName'],
        "%s-service" % (service_dimensions['ServiceName']),
        service_region
    )

    return message

def restartSolrECS(cluster, service, region):
    '''
    Reference: https://github.com/s7anley/aws-ecs-service-stop-lambda/blob/master/main.py
    '''

    client = boto3.client("ecs", region_name=region)
    response = client.list_tasks(cluster=cluster, family=service)
    tasks = response.get('taskArns', [])
    print("Service is running {0} underlying tasks".format(len(tasks)))

    for task in tasks:
        print("Stopping tasks {0}".format(tasks))
        client.stop_task(cluster=cluster, task=task)

    print("Completed service restart")
