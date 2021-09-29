#!/usr/bin/env bats

# Important Notes:
# Solr Admin UI native Login/Logout only supported from 8.6+

# Normally we would run 
# $(CSB) client run-examples --filename examples.json
# ...to test the brokerpak. However, some of our examples need to run nested.
# So, we'll run them manually with eden

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
  bind_name=$2
	echo "Binding the ${SERVICE_NAME}-${uuid} instance"
	$EDEN_EXEC bind -b $bind_name -i "${INSTANCE_NAME}""-$uuid"
}

function unbind () {
  uuid=$1
  bind_name=$2
	echo "Unbinding the ${SERVICE_NAME}-${uuid} instance"
	$EDEN_EXEC unbind -b $bind_name -i "${INSTANCE_NAME}""-$uuid" 2>/dev/null
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

@test 'binding 1A works' {
  # Attempt to login to provision 1 with the bindings for provsion 1
  # Verify that the credentials actually work
  bind_uuid='1'
  bind_name='cred_1A'
  provision_uuid='1'
  bind $bind_uuid $bind_name
  source test.env
  $get_binding $bind_uuid $bind_name $provision_uuid

  # Add DNS for provision
  echo -e "127.0.0.1\t$PROVISION_DOMAIN" | tee -a /etc/hosts

  # Validate that the response is valid json
  curl --user $PROVISION_USER:$PROVISION_PASS "$PROVISION_URI""/solr/admin/authentication" | jq .responseHeader

  # Delete DNS from provision
  cp /etc/hosts hosts
  sed -e "s/127.0.0.1\t$PROVISION_DOMAIN//g" hosts
  cp hosts /etc/hosts
  rm -f hosts
}

@test 'binding 1A != binding 1B' {
  # Verify that bindings are unique

  bind_uuid='1'
  bind_name='cred_1B'
  provision_uuid='1'
  bind $bind_uuid $bind_name

  # Get Binding 1A
  source test.env
  $get_binding '1' 'cred_1A' '1'
  # TODO: Store binding in unique variables

  # Get Binding 1B
  source test.env
  $get_binding '1' 'cred_1B' '1'
  # TODO: Store binding in unique variables

  # TODO: Compare the credentials to each other
}


@test 'provision 2 works' {
  provision '2'
}

@test 'binding 2A works' {
  bind_uuid='2'
  bind_name='cred_2A'
  provision_uuid='2'
  bind $bind_uuid $bind_name
  source test.env
  $get_binding $uuid $bind_name $provision_uuid

  # Add DNS for provision
  echo -e "127.0.0.1\t$PROVISION_1_DOMAIN" | tee -a /etc/hosts

  # Validate that the response is valid json
  curl --user $PROVISION_1_USER:$PROVISION_1_PASS "$PROVISION_1_URI""/solr/admin/authentication" | jq .responseHeader

  # Delete DNS from provision
  cp /etc/hosts hosts
  sed -i -e "s/127.0.0.1\t$PROVISION_DOMAIN//g" hosts
  cp hosts /etc/hosts
  rm -f hosts
}

@test 'bind 2A does not work for provision 1' {
  # Attempt to login to provision 1 with the bindings for provision 2
  # Verify that the credentials for one binding don't work for another
  bind_uuid='2'
  bind_name='cred_2A'
  provision_uuid='1'
  source test.env
  $get_binding $bind_uuid $bind_name $provision_uuid

  # Add DNS for provision
  echo -e "127.0.0.1\t$PROVISION_DOMAIN" | tee -a /etc/hosts

  # Validate that the response rejects credentials
  curl --user $PROVISION_USER:$PROVISION_PASS "$PROVISION_URI""/solr/admin/authentication" | \
    jq '.errorMessages | contains(["No authentication configured"])'

  # Delete DNS from provision
  cp /etc/hosts hosts
  sed -i -e "s/127.0.0.1\t$PROVISION_DOMAIN//g" hosts
  cp hosts /etc/hosts
  rm -f hosts
}

@test 'unbinding 2 works' {
  # Attempt to login to provision 2 with the bindings for provision 2
  # Verify that the credentials have been destroyed
  bind_uuid='2'
  bind_name='cred_2A'
  provision_uuid='2'
  source test.env
  $get_binding $bind_uuid $bind_name $provision_uuid

  # Add DNS for provision
  echo -e "127.0.0.1\t$PROVISION_DOMAIN" | tee -a /etc/hosts

  unbind $bind_uuid $bind_name
  # Validate that the response rejects credentials
  curl --user $PROVISION_USER:$PROVISION_PASS "$PROVISION_URI""/solr/admin/authentication" | \
    jq '.errorMessages | contains(["No authentication configured"])'

  # Delete DNS from provision
  cp /etc/hosts hosts
  sed -i -e "s/127.0.0.1\t$PROVISION_DOMAIN//g" hosts
  cp hosts /etc/hosts
  rm -f hosts
}

@test 'unbinding 1 works' {
  # Attempt to login to provision 2 with the bindings for provision 2
  # Verify that the credentials have been destroyed
  bind_uuid='1'
  bind_name='cred_1A'
  provision_uuid='1'
  source test.env
  $get_binding $bind_uuid $bind_name $provision_uuid

  # Add DNS for provision
  echo -e "127.0.0.1\t$PROVISION_DOMAIN" | tee -a /etc/hosts

  unbind $bind_uuid $bind_name
  # Validate that the response rejects credentials
  curl --user $PROVISION_USER:$PROVISION_PASS "$PROVISION_URI""/solr/admin/authentication" | \
    jq '.errorMessages | contains(["No authentication configured"])'

  # Delete DNS from provision
  cp /etc/hosts hosts
  sed -i -e "s/127.0.0.1\t$PROVISION_DOMAIN//g" hosts
  cp hosts /etc/hosts
  rm -f hosts
}

@test 'deprovision 1 works' {
  deprovision '1'
  clean_up_eden_helm
  delete_examples_json
}

