# Engine the PKI Secret Engine
resource "vault_mount" "pki_engine" {
  path                      = "pki_engine"
  default_lease_ttl_seconds = 3600
  max_lease_ttl_seconds     = 87600
  type                      = "pki"
}
# Configure Root CA CRL
resource "vault_pki_secret_backend_crl_config" "crl_config" {
  depends_on                = [vault_mount.pki_engine]
  backend                   = vault_mount.pki_engine.path
  expiry                    = "8760h"
  disable                   = false
}

# Create Root Certificate
resource "vault_pki_secret_backend_root_cert" "interal_root_cert" {
  depends_on = [vault_mount.pki_engine]
  backend = vault_mount.pki_engine.path

  type = "internal"
  common_name = "${var.env} Root CA"
  ttl = "87600"
  format = "pem"
  private_key_format = "der"
  key_type = "rsa"
  key_bits = 4096
  exclude_cn_from_sans = true
  ou = "My OU"
  organization = var.env
}

# config_urls sets up the endpoints for the configuration URLs.
resource "vault_pki_secret_backend_config_urls" "config_urls" {
  depends_on                = [vault_pki_secret_backend_crl_config.crl_config]
  backend                   = vault_mount.pki_engine.path
  issuing_certificates      = ["${var.vault_addr}/v1/${vault_mount.pki_engine.path}/ca"]
  crl_distribution_points   = ["${var.vault_addr}/v1/${vault_mount.pki_engine.path}/crl"]
}

# Enable Intermediate CA Mount
resource "vault_mount" "pki_engine_int" {
  path                      = "pki_int"
  default_lease_ttl_seconds = 3600
  max_lease_ttl_seconds     = 87600
  type                      = "pki"
}

# Configure Int CA CRL
resource "vault_pki_secret_backend_crl_config" "crl_config_int" {
  depends_on                = [vault_mount.pki_engine_int]
  backend                   = vault_mount.pki_engine_int.path
  expiry                    = "8760h"
  disable                   = false
}

# Create Intermediate Cert CSR
resource "vault_pki_secret_backend_intermediate_cert_request" "intermediate" {
  depends_on = [vault_mount.pki_engine_int]
  backend = "${vault_mount.pki_engine_int.path}"
  type = "internal"
  common_name = "${var.env}.com Intermediate Authority"
}

# Sign Intermediate Cert
resource "vault_pki_secret_backend_root_sign_intermediate" "root" {
  depends_on = [vault_pki_secret_backend_intermediate_cert_request.intermediate]
  backend = "${vault_mount.pki_engine.path}"
  csr = vault_pki_secret_backend_intermediate_cert_request.intermediate.csr
  common_name = "${var.env}.com Intermediate Authority"
  exclude_cn_from_sans = true
  ttl = "87600"
  ou = "My OU"
  organization = var.env
}

# Create intermediate cert
resource "vault_pki_secret_backend_intermediate_set_signed" "intermediate" { 
  backend = vault_mount.pki_engine_int.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.root.certificate
}

# tls-auth-issuer-role creates a Vault role which will have permissions to issue TLS Certs
resource "vault_pki_secret_backend_role" "role" {
  backend             = vault_mount.pki_engine_int.path
  name                = "tls-auth-issuer-role"
  ttl                 = "12h"
  max_ttl             = "8760h"
  allow_subdomains    = true
  enforce_hostnames   = false
  generate_lease      = true
  require_cn          = false
  allowed_other_sans  = ["*"] 
  allow_any_name      = true
  use_csr_common_name = false
}