#!/bin/bash

set -e

# Iterate through examples
# Check examples.json-template to figure the indexes of each configuration

i=$1
# instance_name=$( jq -r ".[$i].provision_params.instance_name" examples.json)
instance_name=test
INSTANCE_NAME=${2:-$instance_name}

example_name=$(jq -r ".[$i].name" examples.json)
echo "Running Example $i: $example_name"

provision_params=$( jq -r ".[$i].provision_params" examples.json)
bind_params=$( jq -r ".[$i].bind_params" examples.json)
service_name=$( jq -r ".[$i].service_name" examples.json)
service_id=$( jq -r ".[$i].service_id" examples.json)
plan_id=$( jq -r ".[$i].plan_id" examples.json)

if (jq ".[$i].description" examples.json | grep -q "(K8S)"); then
  SERVICE_ID=$service_id PLAN_ID=$plan_id SERVICE_NAME=$service_name \
    INSTANCE_NAME=$INSTANCE_NAME K8S_CLOUD_PROVISION_PARAMS="$provision_params" K8S_CLOUD_BIND_PARAMS=$bind_params make k8s-demo-up
  SERVICE_ID=$service_id PLAN_ID=$plan_id SERVICE_NAME=$service_name \
    INSTANCE_NAME=$INSTANCE_NAME make k8s-demo-down
else
  SERVICE_ID=$service_id PLAN_ID=$plan_id SERVICE_NAME=$service_name \
    INSTANCE_NAME=$INSTANCE_NAME ECS_CLOUD_PROVISION_PARAMS="$provision_params" ECS_CLOUD_BIND_PARAMS="$bind_params" make ecs-demo-up
  SERVICE_ID=$service_id PLAN_ID=$plan_id SERVICE_NAME=$service_name \
    INSTANCE_NAME=$INSTANCE_NAME make ecs-demo-down
fi
