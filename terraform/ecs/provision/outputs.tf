output "solr_admin_user" {
  value     = random_uuid.username.result
  sensitive = true
}

output "solr_admin_pass" {
  value     = random_password.password.result
  sensitive = true
}

output "solr_leader_url" {
  value = "https://${local.leader_domain}"
}

output "solr_follower_url" {
  value = "https://${local.follower_domain}"
}

output "solr_follower_individual_urls" {
  value = join(", ", [for i in range(0, var.solrFollowerCount) :
    "https://${local.follower_domain}:${tostring(9000 + i)}"
  ])
}
