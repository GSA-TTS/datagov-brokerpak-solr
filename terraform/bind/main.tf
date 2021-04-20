resource "random_uuid" "username" {}
resource "random_password" "password" {
  length  = 16
  special = false
  #  override_special = "_%@"
}

locals {
  # This is the equivalent of an entry in an auth file managed by htpasswd
  auth_line = "${random_uuid.username.result}:${bcrypt(random_password.password.result)}"
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

# A resource that manages the auth entry for the generated creds
# Solution comes from https://stackoverflow.com/a/57488946
resource "null_resource" "manage_auth_entry" {

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = base64encode(data.template_file.kubeconfig.rendered)
    }
    command = <<-EOF
      kubectl --kubeconfig <(echo $KUBECONFIG | base64 -d) get secret ${local.cloud_name}-creds -ojsonpath={.data.auth} | base64 -d > auth
      echo '${local.auth_line}' >> auth
      kubectl --kubeconfig <(echo $KUBECONFIG | base64 -d) create secret generic ${local.cloud_name}-creds --from-file=auth --dry-run=client -o yaml | \
        kubectl --kubeconfig <(echo $KUBECONFIG | base64 -d) apply -f -
    EOF
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    when        = destroy
    environment = {
      KUBECONFIG = base64encode(data.template_file.kubeconfig.rendered)
    }
    command = <<-EOF
      kubectl --kubeconfig <(echo $KUBECONFIG | base64 -d) get secret ${local.cloud_name}-creds -ojsonpath={.data.auth} | base64 -d | grep -v '${local.auth_line}' > auth
      kubectl --kubeconfig <(echo $KUBECONFIG | base64 -d) create secret generic ${local.cloud_name}-creds --from-file=auth --dry-run=client -o yaml | \
        kubectl --kubeconfig <(echo $KUBECONFIG | base64 -d) apply -f -
    EOF
  }

  depends_on = [
    # Since Terraform can't infer dependencies from the content of our
    # provisioners, it's critical that we use dependencies to ensure external
    # resources exist at the time that they're referenced.
    null_resource.prerequisite_binaries_present,
    data.template_file.kubeconfig,
    local.cloud_name,
    local.auth_line
  ]
}
