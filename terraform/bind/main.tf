resource "random_uuid" "username" {}
resource "random_password" "password" {
  length  = 16
  special = false
  #  override_special = "_%@"
}

locals {
  admin_password   = data.kubernetes_secret.solr_creds.data.admin
  create_user_json = <<-EOF
    {
      "set-user": {
        "${random_uuid.username.result}":"${random_password.password.result}"
      }
    }
  EOF

  delete_user_json = <<-EOF
    {
      "delete-user": ["${random_uuid.username.result}"]
    }
  EOF

  set_role_json = <<-EOF
    {
      "set-user-role": {
        "${random_uuid.username.result}": ["k8s","admin"]
      }
    }
  EOF

  clear_role_json = <<-EOF
    {
      "set-user-role": {
        "${random_uuid.username.result}": null
      }
    }
  EOF
}

# A resource that manages the existence of a user for the duration of the binding
#
# Some useful tricks in use here:
# * Generate a file containing the content of a variable using the BASH "process substitution" <() operator
# * Output just the HTTP status code from curl:
#   https://superuser.com/questions/272265/getting-curl-to-output-http-status-code#comment1567079_442395

resource "null_resource" "manage_solr_user" {
  # The method used below for referencing external resources in a destroy
  # provisioner via triggers comes from
  # https://github.com/hashicorp/terraform/issues/23679#issuecomment-886020367
  triggers = {
    kubeconfig = base64encode(data.template_file.kubeconfig.rendered)
    admin_password = local.admin_password
    delete_user_json = local.delete_user_json
    clear_role_json = local.clear_role_json
    cloud_name = local.cloud_name
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG         = self.triggers.kubeconfig
      ADMIN_PASSWORD     = self.triggers.admin_password
      GENERATED_PASSWORD = random_password.password.result
      CREATE_USER_JSON   = local.create_user_json
      SET_ROLE_JSON      = local.set_role_json
    }
    # Create the binding's Solr user with the generated password
    # Can't reuse containers because they are left in an unpredictable state after a single run
    # Wait for the command to run before deleting the container
    command = <<-EOF
      kubectl --kubeconfig <(echo $KUBECONFIG | base64 -d) run temp1 --image=curlimages/curl --  \
        -s -f -L \
        -o /dev/null \
        -w "%%{http_code}\n" \
        --user admin:$${ADMIN_PASSWORD} \
        'http://${self.triggers.cloud_name}-solrcloud-common/solr/admin/authentication' \
        -H 'Content-type:application/json' --data "$CREATE_USER_JSON"
      kubectl --kubeconfig <(echo $KUBECONFIG | base64 -d) run temp2 --image=curlimages/curl --  \
        -s -f -L \
        -o /dev/null \
        -w "%%{http_code}\n" \
        --user admin:$${ADMIN_PASSWORD} \
        'http://${self.triggers.cloud_name}-solrcloud-common/solr/admin/authorization' \
        -H 'Content-type:application/json' --data "$SET_ROLE_JSON"
      sleep 10
      kubectl --kubeconfig <(echo $KUBECONFIG | base64 -d) delete pod temp2
      kubectl --kubeconfig <(echo $KUBECONFIG | base64 -d) delete pod temp1
    EOF
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    when        = destroy
    environment = {
      KUBECONFIG       = self.triggers.kubeconfig
      ADMIN_PASSWORD   = self.triggers.admin_password
      DELETE_USER_JSON = self.triggers.delete_user_json
      CLEAR_ROLE_JSON  = self.triggers.clear_role_json
    }
    # Delete the binding's Solr user
    # Can't reuse containers because they are left in an unpredictable state after a single run
    # Wait for the command to run before deleting the container
    command = <<-EOF
      kubectl --kubeconfig <(echo $KUBECONFIG | base64 -d) run temp1 --image=curlimages/curl --  \
        -s -f -L \
        -o /dev/null \
        -w "%%{http_code}\n" \
        --user admin:$ADMIN_PASSWORD \
        'http://${self.triggers.cloud_name}-solrcloud-common/solr/admin/authorization' \
        -H 'Content-type:application/json' --data "$CLEAR_ROLE_JSON"
      kubectl --kubeconfig <(echo $KUBECONFIG | base64 -d) run temp2 --image=curlimages/curl --  \
        -s -f -L \
        -o /dev/null \
        -w "%%{http_code}\n" \
        --user admin:$ADMIN_PASSWORD \
        'http://${self.triggers.cloud_name}-solrcloud-common/solr/admin/authentication' \
        -H 'Content-type:application/json' --data "$DELETE_USER_JSON"
      sleep 10
      kubectl --kubeconfig <(echo $KUBECONFIG | base64 -d) delete pod temp2
      kubectl --kubeconfig <(echo $KUBECONFIG | base64 -d) delete pod temp1
    EOF
  }

  depends_on = [
    data.template_file.kubeconfig,
    data.kubernetes_secret.solr_creds,
    data.kubernetes_service.solr_api, # TODO: Use this to create the curl target URL instead of generating the URL ourselves!
    local.cloud_name,
    null_resource.prerequisite_binaries_present,
  ]
}

# Generate a kubeconfig file to be used in the null_resource
data "template_file" "kubeconfig" {
  template = <<-EOF
    apiVersion: v1
    kind: Config
    current-context: terraform
    clusters:
    - name: cluster
      cluster:
        certificate-authority-data: ${var.cluster_ca_certificate}
        server: ${var.server}
    contexts:
    - name: terraform
      context:
        namespace: ${var.namespace}
        cluster: cluster
        user: terraform
    users:
    - name: terraform
      user:
        token: ${base64decode(var.token)}
  EOF
}

# Confirm that the necessary CLI binaries are present
resource "null_resource" "prerequisite_binaries_present" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOF
      which kubectl
    EOF
  }
}
