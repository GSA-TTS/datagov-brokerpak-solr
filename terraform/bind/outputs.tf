
output "uri" { value = var.solr_admin_url }
output "domain" { value = var.solr_admin_url }
output "username" { value = random_uuid.username.result }
output "password" { value = nonsensitive(random_password.password.result) }
