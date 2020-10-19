
.DEFAULT_GOAL := help

CSB_EXEC=docker-compose exec -T broker /bin/cloud-service-broker
EDEN_EXEC=eden --client user --client-secret pass --url http://127.0.0.1:8080
OPERATOR_PROVISION_PARAMS=$(shell cat examples.json |jq '.[] | select(.service_name | contains("solr-operator")) | .provision_params')
OPERATOR_BIND_PARAMS=$(shell cat examples.json |jq '.[] | select(.service_name | contains("solr-operator")) | .bind_params')

clean: ## Bring down the broker service if it's up, clean out the database, and remove created images
	docker-compose down -v --remove-orphans --rmi local

# Rebuild when the Docker Compose, Dockerfile, or anything in services/ changes
# Origin of the subdirectory dependency solution: 
# https://stackoverflow.com/questions/14289513/makefile-rule-that-depends-on-all-files-under-a-directory-including-within-subd#comment19860124_14289872
build: docker-compose.yaml Dockerfile $(shell find services) ## Build the brokerpak(s) and create a docker image for testing it/them
	docker-compose build
	@echo "Exporting brokerpak(s)..."
	@docker-compose run --rm --no-deps --entrypoint "/bin/sh -c 'cp -u * /code' " -w /usr/share/gcp-service-broker/builtin-brokerpaks broker

up: ## Run the broker service with the brokerpak configured. The broker listens on `0.0.0.0:8080`. curl http://127.0.0.1:8080 or visit it in your browser.
	docker-compose up -d

wait: ## Wait 40 seconds, enough time for the DB and broker to stabilize
	@echo "Waiting 40 seconds for the DB and broker to stabilize..."
	@sleep 40
	@docker-compose ps

test: examples.json  ## Execute the brokerpak examples against the running broker
	@echo "Running examples..."
	$(CSB_EXEC) client run-examples --filename examples.json
	# This is supposed to work, but it doesn't... See upstream issue at:
	# https://github.com/pivotal/cloud-service-broker/issues/115
	# Also, some of our examples need to run nested. So, we'll run them manually
	# with eden instead for now... See the target "test-eden"!

test-eden: examples.json
	$(EDEN_EXEC) provision -i testoperator -s solr-operator  -p base -P '$(OPERATOR_PROVISION_PARAMS)'
	$(EDEN_EXEC) bind -b testbinding -i testoperator
	$(EDEN_EXEC) unbind -b testbinding -i testoperator
	$(EDEN_EXEC) deprovision -i testoperator

test-cleanup: ## Clean up data from failed tests
	-$(EDEN_EXEC) unbind -b testbinding -i testoperator
	-$(EDEN_EXEC) deprovision -i testoperator

down: ## Bring the cloud-service-broker service down
	docker-compose down

all: clean build up wait test down ## Clean and rebuild, then bring up the server, run the examples, and bring the system down
.PHONY: all clean build up wait test down

examples.json:
	$(error Copy examples.json-template to examples.json, then edit in your own values)

# Output documentation for top-level targets
# Thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help
help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

