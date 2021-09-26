#!/usr/bin/env bats

# Normally we would run 
# $(CSB) client run-examples --filename examples.json
# ...to test the brokerpak. However, some of our examples need to run nested.
# So, we'll run them manually with eden

function create_examples_json () {
	./generate-examples.sh > examples.json
  export CLOUD_PROVISION_PARAMS=$(cat examples.json |jq '.[] | select(.service_name | contains("solr-cloud")) | .provision_params')
  export CLOUD_BIND_PARAMS=$(cat examples.json |jq '.[] | select(.service_name | contains("solr-cloud")) | .bind_params')
}

function delete_examples_json () {
	rm examples.json 2>/dev/null
}

function provision () {
  # Takes about 180-210 sec
  uuid=$1
  echo "Provisioning the ${SERVICE_NAME}-${uuid} instance"
  $EDEN_EXEC provision -i "${INSTANCE_NAME}""-$uuid" -s "${SERVICE_NAME}" -p ${PLAN_NAME} -P "${CLOUD_PROVISION_PARAMS}"
}

function deprovision () {
  uuid=$1
	echo "Deprovisioning the ${SERVICE_NAME}-${uuid} instance"
	$EDEN_EXEC deprovision -i "${INSTANCE_NAME}""-$uuid" 2>/dev/null
}

function bind () {
  uuid=$1
	echo "Binding the ${SERVICE_NAME}-${uuid} instance"
	$EDEN_EXEC bind -b binding -i "${INSTANCE_NAME}""-$uuid"
}

function unbind () {
  uuid=$1
	echo "Unbinding the ${SERVICE_NAME}-${uuid} instance"
	$EDEN_EXEC unbind -b binding -i "${INSTANCE_NAME}""-$uuid" 2>/dev/null
}

function clean_up_eden_helm () {
	echo "Removing any orphan services from eden"

  # Remove old eden services
  mkdir -p ~/.eden
  touch ~/.eden/config
	rm ~/.eden/config  2>/dev/null
  # Remove old helm releases
  for i in $(helm list -a | grep -oE 'solr-([0-9]|[a-z]){16}'); do helm uninstall $i; done;
	# kubectl delete secret basic-auth1 2>/dev/null
}

@test 'examples.json exists' {
  create_examples_json
  jq -e '.[].name' examples.json > /dev/null 2>&1
  jq -e '.[].description' examples.json > /dev/null 2>&1
  jq -e '.[].service_name' examples.json > /dev/null 2>&1
  jq -e '.[].service_id' examples.json > /dev/null 2>&1
  jq -e '.[].plan_id' examples.json > /dev/null 2>&1
}

@test 'single provision works' {
  clean_up_eden_helm
  provision '1'
}

@test 'single binding works' {
  bind '1'
}

@test 'single unbinding works' {
  #export SERVICE_INFO=$(echo "eden --client user --client-secret pass --url http://127.0.0.1:8080 credentials -b binding -i ${INSTANCE_NAME:-instance-${USER}}")
  #set -e
  #echo "Running tests... (none yet)"
  unbind '1'
}

@test 'single deprovision works' {
  deprovision '1'
  clean_up_eden_helm
  delete_examples_json
}

