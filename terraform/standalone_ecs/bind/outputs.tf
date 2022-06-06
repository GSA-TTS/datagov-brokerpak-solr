
output "uri" { value = var.solr_admin_url }
output "domain" { value = replace(var.solr_admin_url, "https://", "") }
output "username" { value = random_uuid.username.result }
output "password" { value = nonsensitive(random_password.password.result) }

output "solr_admin_user" { value = "(hidden)" }
output "solr_admin_pass" { value = "(hidden)" }
output "solr_admin_url" { value = "(hidden)" }
