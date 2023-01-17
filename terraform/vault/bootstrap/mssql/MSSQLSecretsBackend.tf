# THIS IS FOR DEFAULT APPLICATIONS
resource "vault_mount" "mssql" {
  path = "mssql"
  type = "database"
}


# ALL DATABASE CONNECTIONS NEED TO BE HERE.

resource "vault_database_secret_backend_connection" "dynamic-cert-demo" {
  backend           = vault_mount.mssql.path
  name              = var.db_name
  allowed_roles     = ["${var.db_name}-role"]
  verify_connection = "false"

  mssql {
    connection_url = "sqlserver://sa:Testing123@${var.sql_server_ip}:1433${var.encrypt}"
  }

# This stopped working on the current version of Terraform provider and vault.  Had to hard code above.
# Date is 1/17/2023.
#  data = {
#    username = var.sql_user
#    password = var.sql_pass
#  }
}

resource "vault_database_secret_backend_role" "role" {
  backend             = vault_mount.mssql.path
  name                = "${var.db_name}-role"
  db_name             = vault_database_secret_backend_connection.dynamic-cert-demo.name
  creation_statements = [
    "CREATE LOGIN [{{name}}] WITH PASSWORD = '{{password}}';",
    "CREATE USER [{{name}}] FOR LOGIN [{{name}}];",
    "GRANT SELECT ON SCHEMA::dbo TO [{{name}}];"
  ]
  default_ttl         = 100
}