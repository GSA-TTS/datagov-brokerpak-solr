#!/bin/bash

set -e

CURRENT_CONTEXT=$(kubectl config current-context)
SOLR_CLUSTER_CA_CERTIFICATE=$(kubectl config view --raw -o json | jq -r '.clusters[]| select(.name | contains("'${CURRENT_CONTEXT}'"))  .cluster["certificate-authority-data"]')
SOLR_TOKEN=$(kubectl get secret $( kubectl get serviceaccount default -n default -o json | jq -r '.secrets[0].name' ) -n default -o json | jq -r .data.token)

# We need the Docker-internal control plane URL to be resolved for the CSB
# when running in a container
SOLR_DOCKER_SERVER=$(kind get kubeconfig --internal --name=$(kind get clusters | grep datagov-broker-test) | grep server | cut -d ' ' -f 6-)

# We need the localhost control plan URL to be used for direct access when we
# work outside the CSB
SOLR_LOCALHOST_SERVER=$(kind get kubeconfig --name=$(kind get clusters | grep datagov-broker-test) | grep server | cut -d ' ' -f 6-)

# Generate the environment variables needed for configuring the CSB running in Docker
echo SOLR_SERVER=${SOLR_DOCKER_SERVER} > .env
echo SOLR_TOKEN=${SOLR_TOKEN} >> .env
echo SOLR_CLUSTER_CA_CERTIFICATE=${SOLR_CLUSTER_CA_CERTIFICATE} >> .env
echo SOLR_NAMESPACE=default >> .env
echo SOLR_DOMAIN_NAME=ing.local.domain >> .env

# Generate terraform.tfvars needed for mucking about directly with terraform/provision
cat > terraform/provision/terraform.tfvars << HEREDOC
server="${SOLR_LOCALHOST_SERVER}"
token="${SOLR_TOKEN}"
cluster_ca_certificate="${SOLR_CLUSTER_CA_CERTIFICATE}"
namespace="default"
domain_name="ing.local.domain"
replicas=3
solrImageTag="8.6"
solrJavaMem="-Xms300m -Xmx300m"
cloud_name="example"
solrCpu="1000m"
solrMem="1G"
HEREDOC

# Use the same terraform.tfvars config for mucking about directly with terraform/bind.
cp terraform/provision/terraform.tfvars terraform/bind/terraform.tfvars
