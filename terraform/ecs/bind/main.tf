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
      "delete-user": ["${random_uuid.username.result}"]
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
    admin_username   = var.solr_admin_user
    admin_password   = var.solr_admin_pass
    delete_user_json = local.delete_user_json
    clear_role_json  = local.clear_role_json
    domain           = var.solr_leader_url
    domain_followers = var.solr_follower_individual_urls
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      ADMIN_USERNAME     = self.triggers.admin_username
      ADMIN_PASSWORD     = self.triggers.admin_password
      GENERATED_PASSWORD = random_password.password.result
      CREATE_USER_JSON   = local.create_user_json
      SET_ROLE_JSON      = local.set_role_json
    }
    # Create the binding's Solr user with the generated password
    # Can't reuse containers because they are left in an unpredictable state after a single run
    # Wait for the command to run before deleting the container
    command = <<-EOF
      curl \
        -s -f -L \
        -o /dev/null \
        -w "%%{http_code}\n" \
        --user $${ADMIN_USERNAME}:$${ADMIN_PASSWORD} \
        '${self.triggers.domain}/solr/admin/authentication' \
        -H 'Content-type:application/json' --data "$CREATE_USER_JSON"
      curl \
        -s -f -L \
        -o /dev/null \
        -w "%%{http_code}\n" \
        --user $${ADMIN_USERNAME}:$${ADMIN_PASSWORD} \
        '${self.triggers.domain}/solr/admin/authorization' \
        -H 'Content-type:application/json' --data "$SET_ROLE_JSON"

      solr_follower_urls=(${replace(self.triggers.domain_followers, ",", "")})
      for solr_follower_url in $${solr_follower_urls[@]}
      do
        curl \
          -s -f -L \
          -o /dev/null \
          -w "%%{http_code}\n" \
          --user $${ADMIN_USERNAME}:$${ADMIN_PASSWORD} \
          "$${solr_follower_url}/solr/admin/authentication" \
          -H 'Content-type:application/json' --data "$CREATE_USER_JSON"
        curl \
          -s -f -L \
          -o /dev/null \
          -w "%%{http_code}\n" \
          --user $${ADMIN_USERNAME}:$${ADMIN_PASSWORD} \
          "$${solr_follower_url}/solr/admin/authorization" \
          -H 'Content-type:application/json' --data "$SET_ROLE_JSON"
      done
    EOF
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    when        = destroy
    environment = {
      ADMIN_USERNAME   = self.triggers.admin_username
      ADMIN_PASSWORD   = self.triggers.admin_password
      DELETE_USER_JSON = self.triggers.delete_user_json
      CLEAR_ROLE_JSON  = self.triggers.clear_role_json
    }
    # Delete the binding's Solr user
    # Can't reuse containers because they are left in an unpredictable state after a single run
    # Wait for the command to run before deleting the container
    command = <<-EOF
      curl \
        -s -f -L \
        -o /dev/null \
        -w "%%{http_code}\n" \
        --user $${ADMIN_USERNAME}:$${ADMIN_PASSWORD} \
        '${self.triggers.domain}/solr/admin/authorization' \
        -H 'Content-type:application/json' --data "$CLEAR_ROLE_JSON"
      curl \
        -s -f -L \
        -o /dev/null \
        -w "%%{http_code}\n" \
        --user $${ADMIN_USERNAME}:$${ADMIN_PASSWORD} \
        '${self.triggers.domain}/solr/admin/authentication' \
        -H 'Content-type:application/json' --data "$DELETE_USER_JSON"

      solr_follower_urls=(${replace(self.triggers.domain_followers, ",", "")})
      for solr_follower_url in $${solr_follower_urls[@]}
      do
        curl \
          -s -f -L \
          -o /dev/null \
          -w "%%{http_code}\n" \
          --user $${ADMIN_USERNAME}:$${ADMIN_PASSWORD} \
          "$${solr_follower_url}/solr/admin/authentication" \
          -H 'Content-type:application/json' --data "$CLEAR_ROLE_JSON"
        curl \
          -s -f -L \
          -o /dev/null \
          -w "%%{http_code}\n" \
          --user $${ADMIN_USERNAME}:$${ADMIN_PASSWORD} \
          "$${solr_follower_url}/solr/admin/authorization" \
          -H 'Content-type:application/json' --data "$DELETE_USER_JSON"
      done
    EOF
  }
}
