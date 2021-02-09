
output "uri" {
  value = format("%s://%s:%s@%s",
    "http", # We need to derive this programmatically from the kubernetes_ingress in future. 
    var.username,
    var.password,
    data.kubernetes_ingress.solrcloud-ingress.spec[0].rule[0].host)
}
output "cloud_name" { value = "" }
output "username" { value = "" }
output "password" { value = "" }
