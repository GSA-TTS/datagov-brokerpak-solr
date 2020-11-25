# datagov-brokerpak

## Why this project

The datagov brokerpak is a [cloud-service-broker](https://github.com/pivotal/cloud-service-broker) plugin that makes services
needed by the data.gov team brokerable via the [Open Service Broker API](https://www.openservicebrokerapi.org/) (compatible with Cloud Foundry and Kubernetes), using Terraform. In particular, this brokerpak is used by [`datagov-ssb`](https://github.com/GSA/datagov-ssb) to extend the capabilities of cloud.gov for the purposes of the data.gov team.

For more information about the brokerpak concept, here's a [5-minute lightning
talk](https://www.youtube.com/watch?v=BXIvzEfHil0) from the 2019 Cloud Foundry Summit. You may also want to check out the brokerpak
[introduction](https://github.com/pivotal/cloud-service-broker/blob/master/docs/brokerpak-intro.md)
and
[specification](https://github.com/pivotal/cloud-service-broker/blob/master/docs/brokerpak-specification.md)
docs.

Huge props go to @josephlewis42 of Google for publishing and publicizing the
brokerpak concept, and to the Pivotal team running with the concept!

## Prerequisites

1. `make` is used for executing docker commands in a meaningful build cycle.
1. `jq` is used for running certain tests
1. [Docker Desktop (for Mac or
   Windows)](https://www.docker.com/products/docker-desktop) or [Docker Engine
   (for Linux)](https://www.docker.com/products/container-runtime) is used for  building, serving, and testing the brokerpak.
1. [KinD (Kubernetes-in-Docker)](https://kind.sigs.k8s.io/) is used to provide
   a local k8s for the broker to populate during tests and demos
1. [`eden`](https://github.com/starkandwayne/eden) is used as a client for testing the brokerpak

Run the `make` command by itself for information on the various targets that are available. 

```
$ make
clean      Bring down the broker service if it's up, clean out the database, and remove created images
build      Build the brokerpak(s) and create a docker image for testing it/them
up         Run the broker service with the brokerpak configured. The broker listens on `0.0.0.0:8080`. curl http://127.0.0.1:8080 or visit it in your browser.
wait       Wait 40 seconds, enough time for the DB and broker to stabilize
test       Execute the brokerpak examples against the running broker
down       Bring the cloud-service-broker service down
all        Clean and rebuild, then bring up the server, run the examples, and bring the system down
help       This help
```
Notable targets are described below

## Building and starting the brokerpak 
Run 

```
make build up wait
```

The broker will start and (after about 40 seconds) listen on `0.0.0.0:8080`. You
test that it's responding by running:
```
curl -i -H "X-Broker-API-Version: 2.16" http://user:pass@127.0.0.1:8080/v2/catalog

```
In response you will see a YAML description of the services and plans available
from the brokerpak.

(Note that the `X-Broker-API-version` header is [**required** by the OSBAPI
specification](https://github.com/openservicebrokerapi/servicebroker/blob/master/spec.md#headers).
The broker will reject requests that don't include the header with `412
Precondition Failed`, and browsers will show that status as `Not Authorized`.)

You can also inspect auto-generated documentation for the brokerpak's offerings
by visiting [`http://127.0.0.1:8080/docs`](http://127.0.0.1:8080/docs) in your browser.

## Operating a test/demo Kubernetes environment

### Creating the environment
Create a temporary Kubernetes cluster to test against with KinD:
```
make test-env-up
```
### Tearing down the environment
Run 
```
kind test-env-down
```

## Demonstrating operation

### Spinning up a demo instance

Run
```
make demo-up
```

The examples and values in the `examples.json` file will be used to:
- Provision and bind a solr-operator instance
- Provision and bind a solr-cloud instance

Once the solr-cloud instance is running, you will see a URL for accessing it.
Open that URL in your browser. 

You are likely to see `503 Service Temporarily
Unavailable` as it takes a while for the SolrCloud instance to be ready for
client connections (up to 12 minutes on Bret's workstation). You can monitor the
progress by running:
```
watch kubectl get all -n default
```
When there is at least one `pod/example-solrcloud-<n>` with status showing `Running` and
Ready showing `1/1`, then reload the provided URL in your browser to see the SolrCloud dashboard.

### Spinning down the demo instance

Run
```
make demo-down
```
The examples and values in the `examples.json` file will be used to:
- Unbind and deprovision the solr-cloud instance
- Unbind and deprovision the solr-operator instance

Any stray resources left over from a failed demo will also be removed, so you
can use this command to reset the environment.


## Running tests

### Testing automatically

Run 
```
make test
```

The examples and values in the `examples.json` file will be used for end-to-end
testing of the brokerpak:
- Provision and bind a solr-operator instance
- Provision and bind a solr-cloud instance
- Unbind and deprovision the solr-cloud instance
- Unbind and deprovision the solr-operator instance

### Testing manually

Run 
```
docker-compose exec -T broker /bin/cloud-service-broker client help
```
to get a list of available commands. You can further request help for each
sub-command. Use this command to poke at the browser one request at a time.

For example to see the catalog:
```
docker-compose exec -T broker /bin/cloud-service-broker client catalog
```

You can refer to the content of the `examples.json` file to manually provision
and bind services. For example:

```
docker-compose exec -T broker /bin/cloud-service-broker client provision --instanceid <instancename> --serviceid f145c5aa-4cee-4570-8a95-9a65f0d8d9da  --planid 1779d7d5-874a-4352-b9c4-877be1f0745b --params "$(cat examples.json |jq '.[] | select(.service_name | contains("solr-operator")) | .provision_params')"
```

...and so on.

Using the CLI in this way will give you very precise JSON results for each
query. For a more human-friendly workflow, use `eden` to manually manipulate the
broker.

For example, listing the catalog and provisioning a service instance with `eden`
looks like this:
```
$ export SB_BROKER_URL=http://user:pass@127.0.0.1:8080
$ export SB_BROKER_USERNAME=user
$ export SB_BROKER_PASSWORD=pass
$ eden catalog
$ eden provision -s solr-operator -p base -i <instance-name> -P "$(cat examples.json |jq '.[] | select(.service_name | contains("solr-operator")) | .provision_params')"
$ eden bind -i <instance-name>
$ eden credentials -i <instance-name> -b <binding-name>
```

**NOTE:** The broker requires credentials for an accessible kubernetes cluster (eg in
the cloud, or provided by Docker Desktop) when provisioning services. Currently we have no way to inject
those credentials as `examples`, which are used as test cases, without
compromising them. We've [requested
this capability upstream in the
broker](https://github.com/pivotal/cloud-service-broker/issues/108).

In the meantime you can manipulate the broker manually. 

### Testing manually

Run 
```
docker-compose exec -T broker /bin/cloud-service-broker client help"
```
to get a list of available commands. You can further request help for each
sub-command. Use this command to poke at the browser one request at a time.

For example to see the catalog:
```
docker-compose exec -T broker /bin/cloud-service-broker client catalog"
```

To provision a service, copy `k8s-creds.yml-template` and edit it to
include the correct credentials for an accessible kubernetes service. Then run:

```
docker-compose exec -T broker /bin/cloud-service-broker client provision --instanceid <instancename> --serviceid f145c5aa-4cee-4570-8a95-9a65f0d8d9da  --planid 1779d7d5-874a-4352-b9c4-877be1f0745b --params "$(cat k8s-creds.yml)"
```

...and so on.

Using the CLI in this way will give you very precise JSON results for each
query. For a more human-friendly workflow, use `eden` to manually manipulate the
broker.

For example, listing the catalog and provisioning a service instance with `eden`
looks like this:
```
$ export SB_BROKER_URL=http://user:pass@127.0.0.1:8080
$ export SB_BROKER_USERNAME=user
$ export SB_BROKER_PASSWORD=pass
$ eden catalog
$ eden provision -s solr-operator -p base -i <instance-name> -P "$(cat k8s-creds.yml)"
$ eden bind -i <instance-name>
$ eden credentials -i <instance-name> -b <binding-name>
```

## Tearing down the brokerpak

Run 

```
make down
```

The broker will be stopped.

## Cleaning out the current state

Run 
```
make clean
```
The broker image, database content, and any built brokerpak files will be removed.

## Contributing

See [CONTRIBUTING](CONTRIBUTING.md) for additional information.

## Public domain

This project is in the worldwide [public domain](LICENSE.md). As stated in [CONTRIBUTING](CONTRIBUTING.md):

> This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).
>
> All contributions to this project will be released under the CC0 dedication. By submitting a pull request, you are agreeing to comply with this waiver of copyright interest.

