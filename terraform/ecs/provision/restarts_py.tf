locals {
  # Can't use a Terraform .tftpl template file because the cloud-service-broker only includes
  # .tf files, so we have to do this as a heredoc. This heredoc contains Terraform template 
  # strings so they are escaped here, "%%{" and "$${"
  restarts_app_template = <<PYTHON
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
PYTHON
}
