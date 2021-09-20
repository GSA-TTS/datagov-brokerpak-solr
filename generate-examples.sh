#!/bin/bash

# BASH templating, courtesy of
# https://stackoverflow.com/a/14870510

CURRENT_CONTEXT=$(kubectl config current-context)
CLUSTER_CA_CERTIFICATE=$(kubectl config view --raw -o json | jq -r '.clusters[]| select(.name | contains("'${CURRENT_CONTEXT}'"))  .cluster["certificate-authority-data"]')
TOKEN=$(kubectl get secret $( kubectl get serviceaccount default -n default -o json | jq -r '.secrets[0].name' ) -n default -o json | jq -r .data.token)

# We need the Docker-internal control plane URL to be resolved
SERVER=$(kind get kubeconfig --internal --name=$(kind get clusters | grep datagov-broker-test) | grep server | cut -d ' ' -f 6-)

template() {
  file=examples.json-template
  eval "`printf 'local %s\n' $@`
cat <<EOF
`cat $file`
EOF"
}

template 