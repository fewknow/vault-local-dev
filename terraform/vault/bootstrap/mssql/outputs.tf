output "business_support_it_dev" {
  value = vault_database_secret_backend_connection.business_support_it_dev.name
}

output "mssql_mount" {
  value = vault_mount.mssql.path
}
