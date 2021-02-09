output "cloud_name" { value = local.cloud_name }
output "username" { value = random_uuid.client_username.result }
output "password" { value = random_password.client_password.result }
