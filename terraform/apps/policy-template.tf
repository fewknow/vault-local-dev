resource "vault_policy" "App-policy" {
  name = "${var.app}-policy"

  policy = <<EOT
  path "auth/*" {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
  }
  #Allow token to manage itself
  path "auth/token/create" {
    capabilities = [ "update" ]
  }

  # Allow creating dynamic db creds for this app
  path "mssql/creds/${var.app}*" {
    capabilities = ["read", "list", "create", "update"]
  }

  # Work read mssql secrets engine role config for this app
  path "mssql/roles/${var.app}*" {
    capabilities = [ "read", "list" ]
  }
  EOT
}

resource "vault_policy" "tls-policy" {
  name = "tls-auth-issuer-role-policy"

  policy = <<EOT
path "cert/issue/tls-issuer-role*" {
    capabilities = ["update", "create", "delete", "read"]
    allowed_parameters = {
        "common_name" = [
            "${var.app}.com"
        ]
        "format" = []
        "ttl" = []
    }
}
EOT
}