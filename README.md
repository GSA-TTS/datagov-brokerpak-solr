# datagov-brokerpak-solr

## Why this project

This is a [cloud-service-broker](https://github.com/pivotal/cloud-service-broker) plugin that makes services
needed by the data.gov team brokerable via the [Open Service Broker
API](https://www.openservicebrokerapi.org/) (compatible with Cloud Foundry and
Kubernetes), using Terraform. In particular, this brokerpak is used by
[`datagov-ssb`](https://github.com/GSA/datagov-ssb) to broker instances of either of the following on cloud.gov,
- [SolrCloud](https://solr.apache.org/guide/8_11/solrcloud.html)
- [Solr Standalone](https://solr.apache.org/guide/8_11/a-quick-overview.html)

For more information about the brokerpak concept, here's a [5-minute lightning
talk](https://www.youtube.com/watch?v=BXIvzEfHil0) from the 2019 Cloud Foundry Summit. You may also want to check out the brokerpak
[introduction](https://github.com/pivotal/cloud-service-broker/blob/master/docs/brokerpak-intro.md)
and
[specification](https://github.com/pivotal/cloud-service-broker/blob/master/docs/brokerpak-specification.md)
docs.

Huge props go to @josephlewis42 of Google for publishing and publicizing the
brokerpak concept, and to the Pivotal team running with the concept!


### Related Docs

- [Solr Helm Chart](https://artifacthub.io/packages/helm/apache-solr/solr)
- [Solr Operator Helm Chart](https://artifacthub.io/packages/helm/apache-solr/solr-operator)
- [Solr Official Docs](https://solr.apache.org/guide/8_11/)
- [Solr Operator SolrCloud CRD](https://github.com/apache/solr-operator/blob/main/docs/solr-cloud/solr-cloud-crd.md)

## Prerequisites (solr-cloud)

1. `make` is used for executing docker commands in a meaningful build cycle.
1. `jq` is used for running certain tests
1. [Docker Desktop (for Mac or
   Windows)](https://www.docker.com/products/docker-desktop) or [Docker Engine
   (for Linux)](https://www.docker.com/products/container-runtime) is used for  building, serving, and testing the brokerpak.
1. [KinD (Kubernetes-in-Docker)](https://kind.sigs.k8s.io/) is used to provide
   a local k8s for the broker to populate during tests and demos
1. [`terraform` 1.1.5](https://releases.hashicorp.com/terraform/1.1.5/) is used for local development.

## Prerequisites (solr-on-ecs)

1. `make` is used for executing docker commands in a meaningful build cycle.
1. `jq` is used for running certain tests
1. [Docker Desktop (for Mac or
   Windows)](https://www.docker.com/products/docker-desktop) or [Docker Engine
   (for Linux)](https://www.docker.com/products/container-runtime) is used for  building, serving, and testing the brokerpak.
1. [`terraform` 1.1.5](https://releases.hashicorp.com/terraform/1.1.5/) is used for local development.
1. AWS account credentials (as environment variables) are used for actual service provisioning. The corresponding user must have at least the permissions described in permission-policies.tf. Set at least these variables:
    - AWS_ACCESS_KEY_ID
    - AWS_SECRET_ACCESS_KEY
    - AWS_DEFAULT_REGION

Run the `make` command by itself for information on the various targets that are available. 

```bash
$ make
clean      Bring down the broker service if it is up and clean out the database
build      Build the brokerpak(s)
up         Run the broker service with the brokerpak configured. The broker listens on `0.0.0.0:8080`. curl http://127.0.0.1:8080 or visit it in your browser. 
down       Bring the cloud-service-broker service down
test       Execute the brokerpak examples against the running broker (TODO)
k8s-demo-up    Provision a SolrCloud instance and output the bound credentials
k8s-demo-down  Clean up data left over from tests and demos
ecs-demo-up    Provision a Solr standalone instance (configured for ckan) and output the bound credentials
ecs-demo-down  Clean up data left over from tests and demos
kind-up    Set up a local Kubernetes test environment using KinD
kind-down  Tear down the Kubernetes test environment in KinD
all        Clean and rebuild, start test environment, run the broker, run the examples, and tear the broker and test env down
help       This help
```

Notable targets are described below.

## Providing a test/demo Kubernetes environment (solr-cloud)

To use an existing Kubernetes cluster for testing:

- Ensure that the [solr-operator Helm chart](https://artifacthub.io/packages/helm/apache-solr/solr-operator) is installed (at least 0.5.0)
- Ensure that the [ingress-nginx Helm chart](https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx) is installed
- Set the `SOLR_DOMAIN_NAME` environment variable to the subdomain where `ingress-nginx` resources will be mapped
- Set the `KUBECONFIG` environment variable to point to the kubeconfig file for the cluster
- If your kubeconfig describes multiple clusters, make sure the current cluster is set to the right one

If you don't have an existing Kubernetes cluster, you can create a local test environment in Docker using the Makefile.

### Creating a local k8s environment for testing

Create a temporary Kubernetes cluster to test against with KinD:

```bash
make kind-up
```

### Tearing down the local k8s environment

Run

```bash
make kind-down
```

## Iterating on the Terraform code

To work with the Terraform and target cluster directly (eg not through the CSB or brokerpak), you can generate an appropriate .tfvars file by running:

```bash
make .env
```

From that point on, you can `cd terraform/provision` and iterate with `terraform init/plan/apply/etc`. The same configuration is also available in `terraform/bind`.

(Note if you've been working with the broker the configuration will probably already exist.)

## Building and starting the brokerpak (while the test environment is available)

Run

```bash
make build up 
```

The broker will start and (after about 40 seconds) listen on `0.0.0.0:8080`. You
test that it's responding by running:

```bash
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

## Demonstrating operation

### Spinning up a demo instance

Run

```bash
make k8s-demo-up
```

The examples and values in the `examples.json` file will be used to provision and bind a solr-cloud instance.

It takes a while for the SolrCloud instance to be ready for
client connections (up to 12 minutes on Bret's workstation). You can monitor the
progress by running:

```bash
watch kubectl get all -n default
```

The service will be available once there is at least one `pod/example-solrcloud-<n>` with status showing `Running` and Ready showing `1/1`. The output of `make` will display a URL with credentials for accessing it. Open the provided URL in your browser to see the SolrCloud dashboard.

### Spinning down the demo instance

Run

```bash
make k8s-demo-down
```

The examples and values in the `examples.json` file will be used to unbind and deprovision the solr-cloud instance.

Any stray resources left over from a failed demo will also be removed, so you
can use this command to reset the environment.

### Testing manually

Run

```bash
docker-compose exec -T broker /bin/cloud-service-broker client help"
```

to get a list of available commands. You can further request help for each
sub-command. Use this command to poke at the browser one request at a time.

For example to see the catalog:

```bash
docker-compose exec -T broker /bin/cloud-service-broker client catalog"
```

To provision a service, copy `k8s-creds.yml-template` and edit it to
include the correct credentials for an accessible kubernetes service. Then run:

```bash
docker-compose exec -T broker /bin/cloud-service-broker client provision --instanceid <instancename> --serviceid f145c5aa-4cee-4570-8a95-9a65f0d8d9da  --planid 1779d7d5-874a-4352-b9c4-877be1f0745b --params "$(cat k8s-creds.yml)"
```

...and so on.

## Iterating on the brokerpak itself

To rebuild the brokerpak and launch it, then provision a test instance:

```bash
make down build up eks-demo-up
# Poke and prod 
make eks-demo-down down
```

## Tearing down the brokerpak

Run

```bash
make down
```

The broker will be stopped.

## Cleaning out the current state

Run

```bash
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

