
.DEFAULT_GOAL := help

CSB_EXEC=docker-compose exec -T broker /bin/cloud-service-broker
EDEN_EXEC=eden --client user --client-secret pass --url http://127.0.0.1:8080
OPERATOR_PROVISION_PARAMS=$(shell cat examples.json |jq '.[] | select(.service_name | contains("solr-operator")) | .provision_params')
OPERATOR_BIND_PARAMS=$(shell cat examples.json |jq '.[] | select(.service_name | contains("solr-operator")) | .bind_params')
CLOUD_PROVISION_PARAMS=$(shell cat examples.json |jq '.[] | select(.service_name | contains("solr-cloud")) | .provision_params')
CLOUD_BIND_PARAMS=$(shell cat examples.json |jq '.[] | select(.service_name | contains("solr-cloud")) | .bind_params')

clean: cleanup ## Bring down the broker service if it's up, clean out the database, and remove created images
	docker-compose down -v --remove-orphans --rmi local

# Origin of the subdirectory dependency solution: 
# https://stackoverflow.com/questions/14289513/makefile-rule-that-depends-on-all-files-under-a-directory-including-within-subd#comment19860124_14289872
build: manifest.yml $(shell find services) ## Build the brokerpak(s)
	@docker run --rm --mount type=bind,src=$(PWD),dst=/source --workdir="/source" cfplatformeng/csb pak build .

up: ## Run the broker service with the brokerpak configured. The broker listens on `0.0.0.0:8080`. curl http://127.0.0.1:8080 or visit it in your browser.
	docker-compose up -d

wait: ## Wait 40 seconds, enough time for the DB and broker to stabilize
	@echo "Waiting 40 seconds for the DB and broker to stabilize..."
	@sleep 40
	@docker-compose ps

# Normally we would run 
	# $(CSB_EXEC) client run-examples --filename examples.json
# ...to test the brokerpak. However, some of our examples need to run nested.
# So, we'll run them manually with eden via "demo" and "cleanup" targets.
test: examples.json demo cleanup ## Execute the brokerpak examples against the running broker
	@echo "Running examples..."

demo: examples.json ## Provision a SolrCloud instance and output the bound credentials
	# Provision and bind a solr-operator service
	$(EDEN_EXEC) provision -i operatorinstance -s solr-operator  -p base -P '$(OPERATOR_PROVISION_PARAMS)'
	$(EDEN_EXEC) bind -b operatorbinding -i operatorinstance
	$(EDEN_EXEC) credentials -b operatorbinding -i operatorinstance

	# Provision and bind a solr-cloud instance (using credentials from the
	# operator instance)
	$(EDEN_EXEC) provision -i cloudinstance -s solr-cloud  -p base -P '$(CLOUD_PROVISION_PARAMS)'
	$(EDEN_EXEC) bind -b cloudbinding -i cloudinstance
	$(EDEN_EXEC) credentials -b cloudbinding -i cloudinstance
	
cleanup: examples.json ## Clean up data left over from tests and demos
	# Unbind and deprovision the solr-cloud instance
	-$(EDEN_EXEC) unbind -b cloudbinding -i cloudinstance
	-$(EDEN_EXEC) deprovision -i cloudinstance

	# Unbind and deprovision the solr-operator instance
	-$(EDEN_EXEC) unbind -b operatorbinding -i operatorinstance
	-$(EDEN_EXEC) deprovision -i operatorinstance
	-rm examples.json 2>/dev/null; true

	# Remove any orphan services
	rm ~/.eden/config  2>/dev/null ; true
	helm uninstall solr 2>/dev/null ; true
	helm uninstall zookeeper 2>/dev/null ; true
	kubectl delete role solrcloud-access-read-only 2>/dev/null ; true
	helm uninstall example 2>/dev/null ; true
	kubectl delete role solrcloud-access-all 2>/dev/null ; true
	kubectl delete secret basic-auth1 2>/dev/null ; true
	kubectl delete role zookeeper-zookeeper-operator 2>/dev/null ; true

down: ## Bring the cloud-service-broker service down
	docker-compose down

all: clean build up wait test down ## Clean and rebuild, then bring up the server, run the examples, and bring the system down
.PHONY: all clean build up wait test down demo-up demo-down test-cleanup

examples.json:
	set -e ;\
	export SECRETNAME=$$( kubectl get serviceaccount default -n default -o json | jq -r '.secrets[0].name' ) ;\
	kubectl config view --raw -o go-template-file --template='examples.json-template' > examples.temp ;\
	kubectl get secret $$SECRETNAME -n default -o go-template-file --template='examples.temp' > examples.json
	rm examples.temp

# Output documentation for top-level targets
# Thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help 
help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

