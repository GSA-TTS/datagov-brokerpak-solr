
output "uri" {
  value = format("%s://%s",
    "http", # We need to derive this programmatically from the kubernetes_ingress in future. 
  data.kubernetes_ingress.solrcloud-ingress.spec[0].rule[0].host)
}
output "domain" { value = data.kubernetes_ingress.solrcloud-ingress.spec[0].rule[0].host }
output "username" { value = random_uuid.username.result }
output "password" { value = random_password.password.result }
