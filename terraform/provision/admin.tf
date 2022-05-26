resource "random_uuid" "username" {}
resource "random_password" "password" {
  length  = 16
  special = false
  #  override_special = "_%@"
}

locals {
  create_user_json = <<-EOF
    {
      "set-user": {
        "${random_uuid.username.result}":"${random_password.password.result}"
      }
    }
  EOF

  delete_user_json = <<-EOF
    {
      "delete-user": ["catalog"]
    }
  EOF

  set_role_json = <<-EOF
    {
      "set-user-role": {
        "${random_uuid.username.result}": ["admin"]
      }
    }
  EOF

  clear_role_json = <<-EOF
    {
      "set-user-role": {
        "catalog": null
      }
    }
  EOF
}

resource "null_resource" "create_solr_admin" {
  # The method used below for referencing external resources in a destroy
  # provisioner via triggers comes from
  # https://github.com/hashicorp/terraform/issues/23679#issuecomment-886020367
  triggers = {
    delete_user_json = local.delete_user_json
    clear_role_json  = local.clear_role_json
    domain           = local.domain
    new_username     = random_uuid.username.result
    new_password     = random_password.password.result
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      CREATE_USER_JSON = local.create_user_json
      SET_ROLE_JSON    = local.set_role_json
      # GENERATED_USERNAME = random_uuid.username.result
      # GENERATED_PASSWORD = random_password.password.result
      DELETE_USER_JSON = self.triggers.delete_user_json
      CLEAR_ROLE_JSON  = self.triggers.clear_role_json
    }
    # Create the binding's Solr user with the generated password
    # Can't reuse containers because they are left in an unpredictable state after a single run
    # Wait for the command to run before deleting the container
    command = <<-EOF
      sleep 20;
      curl \
        -s -f -L \
        -o /dev/null \
        -w "%%{http_code}\n" \
        --user 'catalog:Bleeding-Edge' \
        'https://${self.triggers.domain}/solr/admin/authentication' \
        -H 'Content-type:application/json' --data "$CREATE_USER_JSON"
      curl \
        -s -f -L \
        -o /dev/null \
        -w "%%{http_code}\n" \
        --user 'catalog:Bleeding-Edge' \
        'https://${self.triggers.domain}/solr/admin/authorization' \
        -H 'Content-type:application/json' --data "$SET_ROLE_JSON"
      curl \
        -s -f -L \
        -o /dev/null \
        -w "%%{http_code}\n" \
        --user '${self.triggers.new_username}:${self.triggers.new_password}' \
        'https://${self.triggers.domain}/solr/admin/authorization' \
        -H 'Content-type:application/json' --data "$CLEAR_ROLE_JSON"
      curl \
        -s -f -L \
        -o /dev/null \
        -w "%%{http_code}\n" \
        --user '${self.triggers.new_username}:${self.triggers.new_password}' \
        'https://${self.triggers.domain}/solr/admin/authentication' \
        -H 'Content-type:application/json' --data "$DELETE_USER_JSON"
    EOF
  }

  depends_on = [
    aws_ecs_service.solr
  ]
}
