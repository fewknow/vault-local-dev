# We need to use the consul_acl_token_secret_id datasource in order to extract the actual token value.
# Then we expose it through the output block
data "consul_acl_token_secret_id" "backup_token" {
  accessor_id = consul_acl_token.backup.id
}

output "backup_consul_acl_token" {
  value       = data.consul_acl_token_secret_id.backup_token.secret_id
  description = "put into the backup-vars.yml file"
}

output "keys_consul_acl_token" {
  value       = consul_acl_token.keys.id
  description = "Used with something like git2consul"
}

output "ui_write_consul_acl_token" {
  value       = consul_acl_token.ui_write.id
  description = "May not be needed if using git2consul"
}
