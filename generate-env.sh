#!/bin/bash

set -e

CURRENT_CONTEXT=$(kubectl config current-context)
K8S_CLUSTER_CA_CERTIFICATE=$(kubectl config view --raw -o json | jq -r '.clusters[]| select(.name | contains("'${CURRENT_CONTEXT}'"))  .cluster["certificate-authority-data"]')
K8S_TOKEN=$(kubectl get secret $( kubectl get serviceaccount default -n default -o json | jq -r '.secrets[0].name' ) -n default -o json | jq -r .data.token)

# We need the Docker-internal control plane URL to be resolved for the CSB
# when running in a container
K8S_DOCKER_SERVER=$(kind get kubeconfig --internal --name=$(kind get clusters | head -1) | grep server | cut -d ' ' -f 6-)

# We need the localhost control plan URL to be used for direct access when we
# work outside the CSB
K8S_LOCALHOST_SERVER=$(kind get kubeconfig --name=$(kind get clusters | head -1) | grep server | cut -d ' ' -f 6-)

# Generate the environment variables needed for configuring the CSB running in Docker
echo K8S_SERVER=${K8S_DOCKER_SERVER} > .env
echo K8S_TOKEN=${K8S_TOKEN} >> .env
echo K8S_CLUSTER_CA_CERTIFICATE=${K8S_CLUSTER_CA_CERTIFICATE} >> .env
echo K8S_NAMESPACE=default >> .env

# Generate terraform.tfvars needed for mucking about directly with terraform/provision
cat > terraform/provision/terraform.tfvars << HEREDOC
server="${K8S_LOCALHOST_SERVER}"
token="${K8S_TOKEN}"
cluster_ca_certificate="${K8S_CLUSTER_CA_CERTIFICATE}"
namespace="default"
replicas=3
solrImageTag="8.6"
solrJavaMem="-Xms300m -Xmx300m"
cloud_name="example"
HEREDOC