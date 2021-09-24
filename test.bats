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

function clean_up_eden () {
	echo "Removing any orphan services from eden"
	rm ~/.eden/config  2>/dev/null
	helm uninstall example 2>/dev/null
	kubectl delete secret basic-auth1 2>/dev/null
}

@test 'single provision - single binding' {
  create_examples_json
  jq -e '.[].name' examples.json > /dev/null 2>&1
  jq -e '.[].description' examples.json > /dev/null 2>&1
  jq -e '.[].service_name' examples.json > /dev/null 2>&1
  jq -e '.[].service_id' examples.json > /dev/null 2>&1
  jq -e '.[].plan_id' examples.json > /dev/null 2>&1

  provision '1'
  echo "output = ${output}"
  #bind '1'
  #export SERVICE_INFO=$(echo "eden --client user --client-secret pass --url http://127.0.0.1:8080 credentials -b binding -i ${INSTANCE_NAME:-instance-${USER}}")
  #set -e
  #echo "Running tests... (none yet)"
  deprovision '1'
  clean_up_eden
  delete_examples_json
}

