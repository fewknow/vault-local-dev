resource "vault_database_secret_backend_connection" "dynamic-cert-demo" {
  backend           = data.terraform_remote_state.mssql.outputs.mssql_mount
  name              = var.app
  allowed_roles     = ["*"]
  verify_connection = "false"

  mssql {
    connection_url = "sqlserver://{{username}}:{{password}}@${var.server_ip}:1433${var.encrypt}"
  }

  data = {
    username = var.sql_user
    password = var.sql_pass
  }
}

# resource "vault_database_secret_backend_role" "dynamic-cert-demo {
#   backend             = data.terraform_remote_state.mssql.outputs.mssql_mount
#   name                = "${var.app}-role"
#   db_name             = var.app
#   default_ttl         = 3600
#   max_ttl             = 86400
#   creation_statements = [<<-EOT 
#     CREATE LOGIN [{{name}}] WITH PASSWORD = \'{{password}}\'
#     CREATE USER [{{name}}] FOR LOGIN [{{name}}]
#     GRANT SELECT ON SCHEMA::dbo TO [{{name}}]
#   EOT
#   ]
#}


# curl \
#     --header "X-Vault-Token: s.RgB7uuXN1lVNHcgU4fEDdsUj" \
#     --request POST \
#     --data @payload.json \
#     https://127.0.0.1:8200/v1/pki/issue/tls-auth-issuer-role