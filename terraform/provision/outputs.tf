
# Not all of these will be output; most will just be passed on for use in binding
output "namespace" { value = var.namespace }
output "server" { value = var.server }
output "token" { value = var.token }
output "cluster_ca_certificate" { value = var.cluster_ca_certificate }
output "cloud_name" { value = local.cloud_name }
output "username" { value = random_uuid.client_username.result }
output "password" { value = random_password.client_password.result }
