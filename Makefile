
.DEFAULT_GOAL := help

DOCKER_OPTS=--rm -v $(PWD):/brokerpak -w /brokerpak
CSB=ghcr.io/gsa/cloud-service-broker:v0.10.0gsa
SECURITY_USER_NAME := $(or $(SECURITY_USER_NAME), user)
SECURITY_USER_PASSWORD := $(or $(SECURITY_USER_PASSWORD), pass)

BROKER_NAME=solr
K8S_SERVICE_NAME=solr-cloud
K8S_PLAN_NAME=base
K8S_SERVICE_ID='b9013a91-9ce8-4c18-8035-a135a8cd6ff9'
K8S_PLAN_ID='e35e9675-413f-4f42-83de-ad5003357e77'
ECS_SERVICE_NAME=solr-on-ecs
ECS_PLAN_NAME=standalone_ecs
ECS_SERVICE_ID='182612a5-e2b7-4afc-b2b2-9f9d066875d1'
ECS_PLAN_ID='4d7f0501-77d6-4d21-a37a-8b80a0ea9c0d'
INSTANCE_NAME ?= instance-$(USER)

# Execute the cloud-service-broker binary inside the running container
CSB_EXEC=docker exec csb-service-$(BROKER_NAME) /bin/cloud-service-broker

# Generate IDs for the serviceid and planid, formatted like so (suitable for eval):
#   serviceid=SERVICEID
#   planid=PLANID
CSB_SET_ECS_IDS=$(CSB_EXEC) client catalog | jq -r '.response.services[]| select(.name=="$(ECS_SERVICE_NAME)") | {serviceid: .id, planid: .plans[0].id} | to_entries | .[] | "export " + .key + "=" + (.value | @sh)'
CSB_SET_K8S_IDS=$(CSB_EXEC) client catalog | jq -r '.response.services[]| select(.name=="$(K8S_SERVICE_NAME)") | {serviceid: .id, planid: .plans[0].id} | to_entries | .[] | "export " + .key + "=" + (.value | @sh)'

# Wait for an instance operation to complete; append with the instance id
# Wait for an binding operation to complete; append with the instance id and binding id
# Fetch the content of a binding; append with the instance id and binding id
CSB_INSTANCE_WAIT=docker exec csb-service-$(BROKER_NAME) ./bin/instance-wait.sh
CSB_BINDING_WAIT=docker exec csb-service-$(BROKER_NAME) ./bin/binding-wait.sh
CSB_BINDING_FETCH=docker exec csb-service-$(BROKER_NAME) ./bin/binding-fetch.sh

# This doesn't work, so simplify the provision/bind params
# CLOUD_PROVISION_PARAMS=$(shell cat examples.json |jq -r '.[] | select(.service_name | contains("solr-cloud")) | .provision_params')
# CLOUD_BIND_PARAMS=$(shell cat examples.json |jq -r '.[] | select(.service_name | contains("solr-cloud")) | .bind_params')
ECS_CLOUD_PROVISION_PARAMS='{ "solrMem": 12288, "solrCpu": 2048, "solrImageRepo": "ghcr.io/gsa/catalog.data.gov.solr", "solrImageTag": "8-stunnel-root" }'
K8S_CLOUD_PROVISION_PARAMS='{ "solrJavaMem":"-Xms300m -Xmx300m", "solrMem":"1G", "solrCpu":"1000m", "cloud_name":"demo", "solrImageRepo": "ghcr.io/gsa/catalog.data.gov.solr", "solrImageTag": "8-curl" }'
CLOUD_BIND_PARAMS='{}'

PREREQUISITES = docker jq kind kubectl helm
K := $(foreach prereq,$(PREREQUISITES),$(if $(shell which $(prereq)),some string,$(error "Missing prerequisite commands $(prereq)")))


###############################################################################
## General Commands

check:
	@echo CSB_EXEC: $(CSB_EXEC)
	@echo ECS_SERVICE_NAME: $(ECS_SERVICE_NAME)
	@echo ECS_PLAN_NAME: $(ECS_PLAN_NAME)
	@echo ECS_CLOUD_PROVISION_PARAMS: $(ECS_CLOUD_PROVISION_PARAMS)
	@echo K8S_SERVICE_NAME: $(K8S_SERVICE_NAME)
	@echo K8S_PLAN_NAME: $(K8S_PLAN_NAME)
	@echo K8S_CLOUD_PROVISION_PARAMS: $(K8S_CLOUD_PROVISION_PARAMS)
	@echo CLOUD_BIND_PARAMS: $(CLOUD_BIND_PARAMS)

clean: down ## Bring down the broker service if it's up and clean out the database
	@docker rm -f csb-service-$(BROKER_NAME)
	@rm -f datagov-services-pak-*.brokerpak

# Origin of the subdirectory dependency solution:
# https://stackoverflow.com/questions/14289513/makefile-rule-that-depends-on-all-files-under-a-directory-including-within-subd#comment19860124_14289872
build: manifest.yml solr-on-ecs.yml $(shell find terraform) ## Build the brokerpak(s)
	@docker run --user $(shell id -u):$(shell id -g) $(DOCKER_OPTS) $(CSB) pak build

# Healthcheck solution from https://stackoverflow.com/a/47722899
# (Alpine inclues wget, but not curl.)
up: .env.secrets .env ## Run the broker service with the brokerpak configured. The broker listens on `0.0.0.0:8080`. curl http://127.0.0.1:8080 or visit it in your browser.
	docker run $(DOCKER_OPTS) \
	-p 8080:8080 \
	-e SECURITY_USER_NAME=$(SECURITY_USER_NAME) \
	-e SECURITY_USER_PASSWORD=$(SECURITY_USER_PASSWORD) \
	-e "DB_TYPE=sqlite3" \
	-e "DB_PATH=/tmp/csb-db" \
	-e "GSB_DEBUG=true" \
	--env-file .env \
	--env-file .env.secrets \
	--name csb-service-$(BROKER_NAME) \
	-d --network kind \
	--health-cmd="wget --header=\"X-Broker-API-Version: 2.16\" --no-verbose --tries=1 --spider http://$(SECURITY_USER_NAME):$(SECURITY_USER_PASSWORD)@localhost:8080/v2/catalog || exit 1" \
	--health-interval=2s \
	--health-retries=15 \
	$(CSB) serve
	@while [ "`docker inspect -f {{.State.Health.Status}} csb-service-$(BROKER_NAME)`" != "healthy" ]; do   echo "Waiting for csb-service-$(BROKER_NAME) to be ready..." ;  sleep 2; done
	@echo "csb-service-$(BROKER_NAME) is ready!" ; echo ""
	@docker ps -l

down: ## Bring the cloud-service-broker service down
	-@docker stop csb-service-$(BROKER_NAME)

###############################################################################
## Solr on ECS Commands

check-ecs-ids:
	@( \
	eval "$$( $(CSB_SET_ECS_IDS) )" ;\
	echo Service ID: $(ECS_SERVICE_ID) ;\
	echo Plan ID: $(ECS_PLAN_ID) ;\
	)

.env.secrets:
	@echo Copy .env.secrets-template to .env.secrets, then edit in your own values

ecs-all: clean build up ecs-demo-up ecs-demo-down down ## Clean and rebuild, run the broker, provision/bind instance, unbind/deprovision instance, and tear the broker down

ecs-demo-up: ## Provision a Solr instance on ECS and output the bound credentials
	@( \
	set -e ;\
	eval "$$( $(CSB_SET_ECS_IDS) )" ;\
	echo "Provisioning $(ECS_SERVICE_NAME):$(ECS_PLAN_NAME):$(INSTANCE_NAME)" ;\
	$(CSB_EXEC) client provision --serviceid $(ECS_SERVICE_ID) --planid $(ECS_PLAN_ID) --instanceid $(INSTANCE_NAME)                     --params $(CLOUD_PROVISION_PARAMS);\
	$(CSB_INSTANCE_WAIT) $(INSTANCE_NAME) ;\
	echo "Binding $(SERVICE_NAME):$(PLAN_NAME):$(INSTANCE_NAME):binding" ;\
	$(CSB_EXEC) client bind      --serviceid $(ECS_SERVICE_ID) --planid $(ECS_PLAN_ID) --instanceid $(INSTANCE_NAME) --bindingid binding --params $(CLOUD_BIND_PARAMS) | jq -r .response > $(INSTANCE_NAME).binding.json ;\
	)

ecs-demo-down: ## Clean up data left over from tests and demos
	@( \
	set -e ;\
	eval "$$( $(CSB_SET_ECS_IDS) )" ;\
	echo "Unbinding and deprovisioning the ${ECS_SERVICE_NAME} instance";\
	$(CSB_EXEC) client unbind --bindingid binding --instanceid $(INSTANCE_NAME) --serviceid $(ECS_SERVICE_ID) --planid $(ECS_PLAN_ID) 2>/dev/null;\
	$(CSB_EXEC) client deprovision --instanceid $(INSTANCE_NAME) --serviceid $(ECS_SERVICE_ID) --planid $(ECS_PLAN_ID) 2>/dev/null;\
	$(CSB_INSTANCE_WAIT) $(INSTANCE_NAME) ;\
	)

###############################################################################
## SolrCloud on EKS Commands

check-k8s-ids:
	@( \
	eval "$$( $(CSB_SET_K8S_IDS) )" ;\
	echo Service ID: $(K8S_SERVICE_ID) ;\
	echo Plan ID: $(K8S_PLAN_ID) ;\
	)

.env: generate-env.sh
	@echo Generating a .env file containing the k8s config needed by the broker
	@./generate-env.sh

examples.json: examples.json-template
	@./generate-examples.sh > examples.json

k8s-demo-up: ## Provision a SolrCloud instance and output the bound credentials
	@( \
	set -e ;\
	eval "$$( $(CSB_SET_K8S_IDS) )" ;\
	echo "Provisioning $(K8S_SERVICE_NAME):$(K8S_PLAN_NAME):$(INSTANCE_NAME)" ;\
	$(CSB_EXEC) client provision --serviceid $(K8S_SERVICE_ID) --planid $(K8S_PLAN_ID) --instanceid $(INSTANCE_NAME)                     --params $(CLOUD_PROVISION_PARAMS);\
	$(CSB_INSTANCE_WAIT) ${INSTANCE_NAME} ;\
	echo "Binding $(K8S_SERVICE_NAME):$(K8S_PLAN_NAME):$(INSTANCE_NAME):binding" ;\
	$(CSB_EXEC) client bind      --serviceid $(K8S_SERVICE_ID) --planid $(K8S_PLAN_ID) --instanceid $(INSTANCE_NAME) --bindingid binding --params $(CLOUD_BIND_PARAMS) | jq -r .response > $(INSTANCE_NAME).binding.json ;\
	)

k8s-demo-down: ## Clean up data left over from tests and demos
	@( \
	set -e ;\
	eval "$$( $(CSB_SET_K8S_IDS) )" ;\
	echo "Unbinding and deprovisioning the $(SERVICE_NAME) instance";\
	$(CSB_EXEC) client unbind --bindingid binding --instanceid $(INSTANCE_NAME) --serviceid $(K8S_SERVICE_ID) --planid $(K8S_PLAN_ID) 2>/dev/null;\
	$(CSB_EXEC) client deprovision --instanceid $(INSTANCE_NAME) --serviceid $(K8S_SERVICE_ID) --planid $(K8S_PLAN_ID) 2>/dev/null;\
	$(CSB_INSTANCE_WAIT) $(INSTANCE_NAME) ;\
	)

kind-up: ## Set up a Kubernetes test environment using KinD
	# Creating a temporary Kubernetes cluster to test against with KinD
	@kind create cluster --config kind/kind-config.yaml --name datagov-broker-test
	# Grant cluster-admin permissions to the `system:serviceaccount:default:default` Service.
	# (This is necessary for the service account to be able to create the cluster-wide
	# Solr CRD definitions.)
	@kubectl create clusterrolebinding default-sa-cluster-admin --clusterrole=cluster-admin --serviceaccount=default:default --namespace=default
	# Install a KinD-flavored ingress controller (to make the Solr instances visible to the host).
	# See (https://kind.sigs.k8s.io/docs/user/ingress/#ingress-nginx for details.
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.0.1/deploy/static/provider/kind/deploy.yaml
	@kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=270s
	@kubectl apply -f kind/persistent-storage.yml
	# Install the ZooKeeper and Solr operators using Helm
	kubectl create -f https://solr.apache.org/operator/downloads/crds/v0.5.0/all-with-dependencies.yaml
	@helm install --namespace kube-system --repo https://solr.apache.org/charts --version 0.5.0 solr solr-operator

kind-down: ## Tear down the Kubernetes test environment in KinD
	kind delete cluster --name datagov-broker-test
	@rm .env

eks-all: clean build kind-up up k8s-demo-up k8s-demo-down down kind-down ## Clean and rebuild, start local test environment, run the broker, run the examples, and tear the broker and test env down
.PHONY: all clean build up down test kind-up kind-down ecs-demo-up ecs-demo-down k8s-demo-up k8s-demo-down

# Output documentation for top-level targets
# Thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help
help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

