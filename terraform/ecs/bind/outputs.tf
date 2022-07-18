
output "uri" { value = var.solr_leader_url }
output "domain" { value = replace(var.solr_leader_url, "https://", "") }
output "domain_replica" { value = replace(var.solr_follower_url, "https://", "") }
output "username" { value = random_uuid.username.result }
output "password" { value = nonsensitive(random_password.password.result) }

output "solr_admin_user" { value = "(hidden)" }
output "solr_admin_pass" { value = "(hidden)" }
output "solr_follower_url" { value = "(hidden)" }
output "solr_leader_url" { value = "(hidden)" }
output "solr_follower_individual_urls" {}
