
.DEFAULT_GOAL := help

DOCKER_OPTS=--rm -v $(PWD):/brokerpak -w /brokerpak
CSB=ghcr.io/gsa/cloud-service-broker:v2.0.3gsa
SECURITY_USER_NAME := $(or $(SECURITY_USER_NAME), user)
SECURITY_USER_PASSWORD := $(or $(SECURITY_USER_PASSWORD), pass)

BROKER_NAME=solr
SERVICE_NAME ?= solr-on-ecs
PLAN_NAME ?= base
SERVICE_ID ?= '182612a5-e2b7-4afc-b2b2-9f9d066875d1'
PLAN_ID ?= '4d7f0501-77d6-4d21-a37a-8b80a0ea9c0d'

# Specify provsion/bind parameters to run a specific example
INSTANCE_NAME ?= instance-$(USER)
CLOUD_PROVISION_PARAMS ?= '{}'
CLOUD_BIND_PARAMS ?= '{}'

# Execute the cloud-service-broker binary inside the running container
CSB_EXEC=docker exec csb-service-$(BROKER_NAME) /bin/cloud-service-broker

# Wait for an instance operation to complete; append with the instance id
# Wait for an binding operation to complete; append with the instance id and binding id
# Fetch the content of a binding; append with the instance id and binding id
CSB_INSTANCE_WAIT=docker exec csb-service-$(BROKER_NAME) ./bin/instance-wait.sh
CSB_BINDING_WAIT=docker exec csb-service-$(BROKER_NAME) ./bin/binding-wait.sh
CSB_BINDING_FETCH=docker exec csb-service-$(BROKER_NAME) ./bin/binding-fetch.sh

PREREQUISITES = docker jq kind kubectl helm
K := $(foreach prereq,$(PREREQUISITES),$(if $(shell which $(prereq)),some string,$(error "Missing prerequisite commands $(prereq)")))


###############################################################################
## General Commands

check:
	@echo CSB_EXEC: $(CSB_EXEC)
	@echo SERVICE_NAME: $(SERVICE_NAME)
	@echo PLAN_NAME: $(PLAN_NAME)
	@echo CLOUD_PROVISION_PARAMS: $(CLOUD_PROVISION_PARAMS)
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
up: .env.secrets ## Run the broker service with the brokerpak configured. The broker listens on `0.0.0.0:8080`. curl http://127.0.0.1:8080 or visit it in your browser.
	docker run $(DOCKER_OPTS) \
	-p 8080:8080 \
	-e SECURITY_USER_NAME=$(SECURITY_USER_NAME) \
	-e SECURITY_USER_PASSWORD=$(SECURITY_USER_PASSWORD) \
	-e "DB_TYPE=sqlite3" \
	-e "DB_PATH=/tmp/csb-db" \
	-e "GSB_DEBUG=true" \
	--env-file .env.secrets \
	--name csb-service-$(BROKER_NAME) \
  -d \
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

.env.secrets:
	@echo Copy .env.secrets-template to .env.secrets, then edit in your own values

ecs-all: clean build up demo-up demo-down down ## Clean and rebuild, run the broker, provision/bind instance, unbind/deprovision instance, and tear the broker down

demo-up: ## Provision a Solr instance on ECS and output the bound credentials
	@( \
	set -e ;\
	echo "Provisioning $(SERVICE_NAME):$(PLAN_NAME):$(INSTANCE_NAME)" ;\
	$(CSB_EXEC) client provision --serviceid $(SERVICE_ID) --planid $(PLAN_ID) --instanceid "$(INSTANCE_NAME)"                     --params '$(CLOUD_PROVISION_PARAMS)';\
	$(CSB_INSTANCE_WAIT) $(INSTANCE_NAME) ;\
	echo "Binding $(SERVICE_NAME):$(PLAN_NAME):$(INSTANCE_NAME):binding" ;\
	$(CSB_EXEC) client bind      --serviceid $(SERVICE_ID) --planid $(PLAN_ID) --instanceid "$(INSTANCE_NAME)" --bindingid binding --params "$(CLOUD_BIND_PARAMS)" | jq -r .response > $(INSTANCE_NAME).binding.json ;\
	)

demo-down: ## Clean up data left over from tests and demos
	@( \
	set -e ;\
	echo "Unbinding and deprovisioning the ${SERVICE_NAME} instance";\
	$(CSB_EXEC) client unbind --bindingid binding --instanceid $(INSTANCE_NAME) --serviceid $(SERVICE_ID) --planid $(PLAN_ID) 2>/dev/null;\
	$(CSB_EXEC) client deprovision --instanceid $(INSTANCE_NAME) --serviceid $(SERVICE_ID) --planid $(PLAN_ID) 2>/dev/null;\
	$(CSB_INSTANCE_WAIT) $(INSTANCE_NAME) ;\
	)


# Output documentation for top-level targets
# Thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help
help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

