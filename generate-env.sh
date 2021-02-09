#!/bin/bash

set -e

CURRENT_CONTEXT=$(kubectl config current-context)
K8S_CLUSTER_CA_CERTIFICATE=$(kubectl config view --raw -o json | jq -r '.clusters[]| select(.name | contains("'${CURRENT_CONTEXT}'"))  .cluster["certificate-authority-data"]')
K8S_TOKEN=$(kubectl get secret $( kubectl get serviceaccount default -n default -o json | jq -r '.secrets[0].name' ) -n default -o json | jq -r .data.token)

# We need the Docker-internal control plane URL to be resolved
K8S_SERVER=$(kind get kubeconfig --internal --name=$(kind get clusters | head -1) | grep server | cut -d ' ' -f 6-)

echo K8S_SERVER=${K8S_SERVER} > .env
echo K8S_TOKEN=${K8S_TOKEN} >> .env
echo K8S_CLUSTER_CA_CERTIFICATE=${K8S_CLUSTER_CA_CERTIFICATE} >> .env
echo K8S_NAMESPACE=default >> .env
