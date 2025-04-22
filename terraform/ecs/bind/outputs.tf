
output "uri" { value = var.solr_leader_url }
output "domain" { value = replace(var.solr_leader_url, "https://", "") }
output "domain_replica" { value = replace(var.solr_follower_url, "https://", "") }
output "username" { value = random_uuid.username.result }
output "password" { value = nonsensitive(random_password.password.result) }

# all users are admins, so including this does not change security risk
# but it does allow using these to fix broken clusters
output "solr_admin_user" { value = var.solr_admin_user }
output "solr_admin_pass" { value = var.solr_admin_pass }

output "solr_follower_url" { value = "(hidden)" }
output "solr_leader_url" { value = "(hidden)" }
output "solr_follower_individual_urls" { value = var.solr_follower_individual_urls }
