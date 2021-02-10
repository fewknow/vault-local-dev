provider "vault" {
  # This will default to using $VAULT_ADDR
  address = "https://127.0.0.1:8200"
  token   = var.vault_token
}

terraform {
  required_providers {
    vault = "< 3.0.0"
  }
}

resource "vault_pki_secret_backend_cert" "app_cert" {
  backend      = var.pki-int-path
  name         = "tls-auth-issuer-role"
  common_name  = "${var.app}.local-vault.com"
  format       = "pem"
  #private_key_format = "pem"
  ttl          = "24h"
}

resource "vault_cert_auth_backend_role" "app_cert_role" {
  name                 = var.app
  certificate          = vault_pki_secret_backend_cert.app_cert.certificate
  backend              = var.cert-path
  allowed_common_names = ["${var.app}.local-vault.com"]
  token_ttl            = 300
  token_max_ttl        = 2628000
  token_policies       = ["${var.app}-policy"]
}

resource "local_file" "cert" {
    content     = vault_pki_secret_backend_cert.app_cert.certificate
    filename = "../../../config/${var.app}/${var.app}.crt"
}

resource "local_file" "key" {
    content     = vault_pki_secret_backend_cert.app_cert.private_key
    filename = "../../../config/${var.app}/${var.app}.key"
}