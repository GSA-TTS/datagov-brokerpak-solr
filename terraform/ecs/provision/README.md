# How to iterate on the provisioning code

You can develop and test the Terraform code for provisioning in isolation from
the broker context here.

1. Copy `terraform.tfvars-template` to `terraform.tfvars`, then edit the content
   appropriately. In particular, customize the `instance` and `subdomain`
   parameters to avoid collisions in the target AWS account!

1. Copy the `.env.secrets` file from the top-level of this repository for AWS access credentials.

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
    $ docker run -v `pwd`:`pwd` -w `pwd` -e HOME=`pwd` --user $(id -u):$(id -g) --env-file .env.secrets -e TERM -it --rm default-provision:latest

    [within the container]
    tofu init
    tofu apply -auto-approve
    [tinker in your editor, run tofu apply, inspect the cluster, repeat]
    tofu destroy -auto-approve
    exit
    ```
