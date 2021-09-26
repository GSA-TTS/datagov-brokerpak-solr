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

@test 'provision 1 works' {
  clean_up_eden_helm
  provision '1'
}

@test 'binding 1 works' {
  bind '1'
}

@test 'provision 2 works' {
  # provision '2'
}

@test 'binding 2 works' {
  # bind '2'
}

@test 'bind 1 works for provision 1' {
  export PROVISION_1_URI=$($EDEN_EXEC credentials -i instance-kalima-1 -b solr-cloud-binding | jq -r .uri)
  export PROVISION_1_USER=$($EDEN_EXEC credentials -i instance-kalima-1 -b solr-cloud-binding | jq -r .username)
  export PROVISION_1_PASS=$($EDEN_EXEC credentials -i instance-kalima-1 -b solr-cloud-binding | jq -r .password)
}

@test 'bind 2 does not work for provision 1' {

}

@test 'unbinding 2 works' {
  unbind '1'
}

@test 'bind 2 does not work for provison 2' {

}

@test 'unbinding 1 works' {

}

@test 'deprovision 1 works' {
  deprovision '1'
  clean_up_eden_helm
  delete_examples_json
}

