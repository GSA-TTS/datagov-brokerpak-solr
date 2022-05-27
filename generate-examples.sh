#!/bin/bash

# BASH templating, courtesy of
# https://stackoverflow.com/a/14870510

CURRENT_CONTEXT=$(kubectl config current-context)
CLUSTER_CA_CERTIFICATE=$(kubectl config view --raw -o json | jq -r '.clusters[]| select(.name | contains("'${CURRENT_CONTEXT}'"))  .cluster["certificate-authority-data"]')
TOKEN=$(kubectl get secret $( kubectl get serviceaccount default -n default -o json | jq -r '.secrets[0].name' ) -n default -o json | jq -r .data.token)

CURRENT_CLUSTER=$(kubectl config view --raw -o json | jq -r '.contexts[]| select(.name | contains("'${CURRENT_CONTEXT}'"))  .context.cluster')
SERVER=$(kubectl config view --raw -o json | jq -r '.clusters[]| select(.name | contains("'${CURRENT_CLUSTER}'"))  .cluster["server"]')

template() {
  file=examples.json-template
  eval "`printf 'local %s\n' $@`
cat <<EOF
`cat $file`
EOF"
}

template
