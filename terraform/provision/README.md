# How to iterate on the provisioning code

**WARNING: Communication to the KinD Cluster doesn't currently exist from this
container.  This needs to be established before terraform can work in this 
container.**

You can develop and test the Terraform code for provisioning in isolation from
the broker context here.

1. Copy `terraform.tfvars-template` to `terraform.tfvars`, then edit the content
   appropriately. In particular, customize the `instance` and `subdomain`
   parameters to avoid collisions in the target AWS account!

1. In order to have a development environment consistent with other
   collaborators, we use a special Docker image with the exact CLI binaries we
   want for testing. Doing so will avoid [discrepancies we've noted between development under OS X and W10](https://github.com/terraform-aws-modules/terraform-aws-eks/issues/1262#issuecomment-932792757).

   First, build the image:

    ```bash
    docker build -t default-provision:latest .
    ```

1. Then, start a shell inside a container based on this image. The parameters
   here carry some of your environment variables into that shell, and ensure
   that you'll have permission to remove any files that get created.

    ```bash
    $ docker run -v `pwd`:`pwd` -w `pwd` -e HOME=`pwd` --user $(id -u):$(id -g) -e TERM -it --rm default-provision:latest

    [within the container]
    terraform init
    terraform apply -auto-approve
    [tinker in your editor, run terraform apply, inspect the cluster, repeat]
    terraform destroy -auto-approve
    exit

