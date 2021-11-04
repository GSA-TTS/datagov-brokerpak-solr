
.DEFAULT_GOAL := help

DOCKER_OPTS=--rm -v $(PWD):/brokerpak -w /brokerpak
CSB=ghcr.io/gsa/cloud-service-broker:v0.4.1gsa
SECURITY_USER_NAME := $(or $(SECURITY_USER_NAME), user)
SECURITY_USER_PASSWORD := $(or $(SECURITY_USER_PASSWORD), pass)

CLOUD_PROVISION_PARAMS=$(shell cat examples.json |jq '.[] | select(.service_name | contains("solr-cloud")) | .provision_params')
CLOUD_BIND_PARAMS=$(shell cat examples.json |jq '.[] | select(.service_name | contains("solr-cloud")) | .bind_params')

PREREQUISITES = docker jq kind kubectl helm eden bats
K := $(foreach prereq,$(PREREQUISITES),$(if $(shell which $(prereq)),some string,$(error "Missing prerequisite commands $(prereq)")))

check: SHELL:=./test_env_load
check:
	@echo EDEN_EXEC: $${EDEN_EXEC}
	@echo SERVICE_NAME: $${SERVICE_NAME}
	@echo PLAN_NAME: $${PLAN_NAME}
	@echo CLOUD_PROVISION_PARAMS: $${CLOUD_PROVISION_PARAMS}
	@echo CLOUD_BIND_PARAMS: $${CLOUD_BIND_PARAMS}

clean: SHELL:=./test_env_load
clean: down ## Bring down the broker service if it's up and clean out the database
	@docker rm -f csb-service-$${SERVICE_NAME}
	@rm datagov-services-pak-*.brokerpak

# Origin of the subdirectory dependency solution: 
# https://stackoverflow.com/questions/14289513/makefile-rule-that-depends-on-all-files-under-a-directory-including-within-subd#comment19860124_14289872
build: manifest.yml solr-cloud.yml $(shell find terraform) ## Build the brokerpak(s)
	@docker run --user $(shell id -u):$(shell id -g) $(DOCKER_OPTS) $(CSB) pak build

# Healthcheck solution from https://stackoverflow.com/a/47722899 
# (Alpine inclues wget, but not curl.)
up: SHELL:=./test_env_load
up: .env ## Run the broker service with the brokerpak configured. The broker listens on `0.0.0.0:8080`. curl http://127.0.0.1:8080 or visit it in your browser. 
	docker run $(DOCKER_OPTS) \
	-p 8080:8080 \
	-e SECURITY_USER_NAME=$(SECURITY_USER_NAME) \
	-e SECURITY_USER_PASSWORD=$(SECURITY_USER_PASSWORD) \
	-e "DB_TYPE=sqlite3" \
	-e "DB_PATH=/tmp/csb-db" \
	-e "GSB_DEBUG=true" \
	--env-file .env \
	--name csb-service-$${SERVICE_NAME} \
	-d --network kind \
	--health-cmd="wget --header=\"X-Broker-API-Version: 2.16\" --no-verbose --tries=1 --spider http://$(SECURITY_USER_NAME):$(SECURITY_USER_PASSWORD)@localhost:8080/v2/catalog || exit 1" \
	--health-interval=2s \
	--health-retries=15 \
	$(CSB) serve
	@while [ "`docker inspect -f {{.State.Health.Status}} csb-service-$${SERVICE_NAME}`" != "healthy" ]; do   echo "Waiting for csb-service-$${SERVICE_NAME} to be ready..." ;  sleep 2; done
	@echo "csb-service-$${SERVICE_NAME} is ready!" ; echo ""
	@docker ps -l

down: SHELL:=./test_env_load
down: ## Bring the cloud-service-broker service down
	-@docker stop csb-service-$${SERVICE_NAME}

test: SHELL:=./test_env_load
test: ## Execute the brokerpak examples against the running broker
	sudo chmod 766 /etc/hosts
	bats test.bats
	sudo chmod 744 /etc/hosts

examples.json: examples.json-template
	@./generate-examples.sh > examples.json

demo-up: SHELL:=./test_env_load
demo-up: examples.json ## Provision a SolrCloud instance and output the bound credentials
	./generate-examples.sh > examples.json
	@$${EDEN_EXEC} provision -i $${INSTANCE_NAME} -s $${SERVICE_NAME} -p $${PLAN_NAME} -P '$(CLOUD_PROVISION_PARAMS)'
	@$${EDEN_EXEC} bind -b binding -i $${INSTANCE_NAME}

demo-down: SHELL:=./test_env_load
demo-down: examples.json ## Clean up data left over from tests and demos
	@echo "Unbinding and deprovisioning the ${SERVICE_NAME} instance"
	-@$${EDEN_EXEC} unbind -b binding -i $${INSTANCE_NAME} 2>/dev/null
	-@$${EDEN_EXEC} deprovision -i $${INSTANCE_NAME} 2>/dev/null

	-@rm examples.json 2>/dev/null; true

	@echo "Removing any orphan services from eden"
	-@rm ~/.eden/config  2>/dev/null ; true
	-@helm uninstall example 2>/dev/null ; true
	-@kubectl delete secret basic-auth1 2>/dev/null ; true

test-env-up: ## Set up a Kubernetes test environment using KinD
	# Creating a temporary Kubernetes cluster to test against with KinD
	@kind create cluster --config kind-config.yaml --name datagov-broker-test
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
	# Install the ZooKeeper and Solr operators using Helm
	# TODO: Update the CRD installation in the eks-brokerpak as well
	kubectl create -f https://solr.apache.org/operator/downloads/crds/v0.4.0/all-with-dependencies.yaml
	@helm install --namespace kube-system --repo https://solr.apache.org/charts --version 0.4.0 solr solr-operator

.env: $(HOME)/.kube/config generate-env.sh
	@echo Generating a .env file containing k8s config for the broker
	@./generate-env.sh > .env

test-env-down: ## Tear down the Kubernetes test environment in KinD
	kind delete cluster --name datagov-broker-test
	@rm .env

all: clean build test-env-up up test down test-env-down ## Clean and rebuild, start test environment, run the broker, run the examples, and tear the broker and test env down
.PHONY: all clean build up down test test-env-up test-env-down

# Output documentation for top-level targets
# Thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help 
help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

