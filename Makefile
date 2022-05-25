
.DEFAULT_GOAL := help

DOCKER_OPTS=--rm -v $(PWD):/brokerpak -w /brokerpak
CSB=ghcr.io/gsa/cloud-service-broker:v0.10.0gsa
SECURITY_USER_NAME := $(or $(SECURITY_USER_NAME), user)
SECURITY_USER_PASSWORD := $(or $(SECURITY_USER_PASSWORD), pass)

# Execute the cloud-service-broker binary inside the running container
CSB_EXEC=docker exec csb-service-$(SERVICE_NAME) /bin/cloud-service-broker

# Generate IDs for the serviceid and planid, formatted like so (suitable for eval):
#   serviceid=SERVICEID
#   planid=PLANID
CSB_SET_IDS=$(CSB_EXEC) client catalog | jq -r '.response.services[]| select(.name=="$(SERVICE_NAME)") | {serviceid: .id, planid: .plans[0].id} | to_entries | .[] | "export " + .key + "=" + (.value | @sh)'

# Wait for an instance operation to complete; append with the instance id
CSB_INSTANCE_WAIT=docker exec csb-service-$(SERVICE_NAME) ./bin/instance-wait.sh

# Wait for an binding operation to complete; append with the instance id and binding id
CSB_BINDING_WAIT=docker exec csb-service-$(SERVICE_NAME) ./bin/binding-wait.sh

# Fetch the content of a binding; append with the instance id and binding id
CSB_BINDING_FETCH=docker exec csb-service-$(SERVICE_NAME) ./bin/binding-fetch.sh

CLOUD_PROVISION_PARAMS=$(shell cat examples.json |jq '.[] | select(.service_name | contains("solr-cloud")) | .provision_params')
CLOUD_BIND_PARAMS=$(shell cat examples.json |jq '.[] | select(.service_name | contains("solr-cloud")) | .bind_params')

PREREQUISITES = docker jq kind kubectl helm bats
K := $(foreach prereq,$(PREREQUISITES),$(if $(shell which $(prereq)),some string,$(error "Missing prerequisite commands $(prereq)")))

check: SHELL:=./test_env_load
check:
	@echo CSB_EXEC: $${CSB_EXEC}
	@echo SERVICE_NAME: $${SERVICE_NAME}
	@echo PLAN_NAME: $${PLAN_NAME}
	@echo CLOUD_PROVISION_PARAMS: $${CLOUD_PROVISION_PARAMS}
	@echo CLOUD_BIND_PARAMS: $${CLOUD_BIND_PARAMS}

clean: SHELL:=./test_env_load
clean: down ## Bring down the broker service if it's up and clean out the database
	@docker rm -f csb-service-$${SERVICE_NAME}
	@rm -f datagov-services-pak-*.brokerpak

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

check-ids:
	@( \
	eval "$$( $(CSB_SET_IDS) )" ;\
	echo Service ID: $$serviceid ;\
	echo Plan ID: $$planid ;\
	)

examples.json: examples.json-template
	@./generate-examples.sh > examples.json

demo-up: SHELL:=./test_env_load
demo-up: examples.json ## Provision a SolrCloud instance and output the bound credentials
	./generate-examples.sh > examples.json
	@( \
	set -e ;\
	eval "$$( $(CSB_SET_IDS) )" ;\
	echo "Provisioning ${SERVICE_NAME}:${PLAN_NAME}:${INSTANCE_NAME}" ;\
	$(CSB_EXEC) client provision --serviceid $$serviceid --planid $$planid --instanceid ${INSTANCE_NAME}                     --params $(CLOUD_PROVISION_PARAMS) 2>&1 > /dev/null ;\
	$(CSB_INSTANCE_WAIT) ${INSTANCE_NAME} ;\
	echo "Binding ${SERVICE_NAME}:${PLAN_NAME}:${INSTANCE_NAME}:binding" ;\
	$(CSB_EXEC) client bind      --serviceid $$serviceid --planid $$planid --instanceid ${INSTANCE_NAME} --bindingid binding --params $(CLOUD_BIND_PARAMS) | jq -r .response > ${INSTANCE_NAME}.binding.json ;\
	)

demo-down: SHELL:=./test_env_load
demo-down: examples.json ## Clean up data left over from tests and demos
	@echo "Unbinding and deprovisioning the ${SERVICE_NAME} instance"
	-@$${CSB_EXEC} unbind -b binding -i $${INSTANCE_NAME} 2>/dev/null
	-@$${CSB_EXEC} deprovision -i $${INSTANCE_NAME} 2>/dev/null

	-@rm examples.json 2>/dev/null; true

.env: generate-env.sh
	@echo Generating a .env file containing the k8s config needed by the broker
	@./generate-env.sh

.env.secrets:
  $(error Copy .env.secrets-template to .env.secrets, then edit in your own values)

all: clean build kind-up up test down kind-down ## Clean and rebuild, start local test environment, run the broker, run the examples, and tear the broker and test env down
.PHONY: all clean build up down test kind-up kind-down

# Output documentation for top-level targets
# Thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help
help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

