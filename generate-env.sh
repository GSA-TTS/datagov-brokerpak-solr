#!/bin/bash

set -e

CURRENT_CONTEXT=$(kubectl config current-context)
CURRENT_CLUSTER=$(kubectl config view --raw -o json | jq -r '.contexts[]| select(.name | contains("'"${CURRENT_CONTEXT}"'"))  .context.cluster')
CURRENT_USER=$(kubectl config view --raw -o json | jq -r '.contexts[]| select(.name | contains("'"${CURRENT_CONTEXT}"'"))  .context.user')
SOLR_CLUSTER_CA_CERTIFICATE=$(kubectl config view --raw -o json | jq -r '.clusters[]| select(.name | contains("'"${CURRENT_CLUSTER}"'"))  .cluster["certificate-authority-data"]')
SOLR_TOKEN=$(echo -n `kubectl config view --raw -o json | jq -r '.users[]| select(.name | contains("'"${CURRENT_USER}"'"))  .user["token"]'` | base64 -w 0)
SOLR_SERVER=$(kubectl config view --raw -o json | jq -r '.clusters[]| select(.name | contains("'"${CURRENT_CLUSTER}"'"))  .cluster["server"]')

SOLR_DOMAIN_NAME=${SOLR_DOMAIN_NAME:-ing.local.domain}

if [[ "${CURRENT_CLUSTER}" == "kind-datagov-broker-test" ]]; then
    # If the test cluster is in KinD we need the CSB to use
    # a control plane URL resolvable from inside the CSB Docker container
    CURRENT_USER=kind-datagov-broker-test
    SOLR_CP_SERVER=$(kind get kubeconfig --internal --name="$(kind get clusters | grep datagov-broker-test)" | grep server | cut -d ' ' -f 6-)
    SOLR_TOKEN=$(kubectl get secret $(kubectl get secrets | grep -oh "default-token-[a-z]*\s") -o json | jq .data.token | tr -d '"')
    if [[ "$SOLR_TOKEN" == "null" ]]; then
        # The format of the secret is different if there are more than one token associated with a secret.
        # The first token works reliably
        SOLR_TOKEN=$(kubectl get secret $(kubectl get secrets | grep -oh "default-token-[a-z]*\s") -o json | jq .items[0].data.token | tr -d '"')
    fi
else
    # Otherwise it's the same as the normal server control plane URL
    SOLR_CP_SERVER=${SOLR_SERVER}
fi

# Generate the environment variables needed for configuring the CSB running in Docker
cat > .env << HEREDOC
SOLR_SERVER=${SOLR_CP_SERVER}
SOLR_TOKEN=${SOLR_TOKEN}
SOLR_CLUSTER_CA_CERTIFICATE=${SOLR_CLUSTER_CA_CERTIFICATE}
SOLR_NAMESPACE=default
SOLR_DOMAIN_NAME=${SOLR_DOMAIN_NAME}
HEREDOC

# Generate terraform.tfvars needed for mucking about directly with terraform/provision
cat > terraform/solrcloud/provision/terraform.tfvars << HEREDOC
server="${SOLR_CP_SERVER}"
token="${SOLR_TOKEN}"
cluster_ca_certificate="${SOLR_CLUSTER_CA_CERTIFICATE}"
namespace="default"
domain_name="${SOLR_DOMAIN_NAME}"
replicas=3
solrImageTag="8.11"
solrJavaMem="-Xms300m -Xmx300m"
cloud_name="example"
solrCpu="1000m"
solrMem="1G"
restartCron="*/10 * * * *"
HEREDOC

# Use the same terraform.tfvars config for mucking about directly with terraform/bind.
cp terraform/solrcloud/provision/terraform.tfvars terraform/solrcloud/bind/terraform.tfvars
