# Engine the PKI Secret Engine
resource "vault_mount" "pki_engine" {
  path                      = "pki_engine"
  default_lease_ttl_seconds = 3600
  max_lease_ttl_seconds     = 87600
  type                      = "pki"
}

resource "vault_pki_secret_backend_crl_config" "crl_config" {
  depends_on                = [vault_mount.pki_engine]
  backend                   = vault_mount.pki_engine.path
  expiry                    = "8760h"
  disable                   = false
}

resource "vault_mount" "pki_engine_int" {
  path                      = "pki_int"
  default_lease_ttl_seconds = 3600
  max_lease_ttl_seconds     = 87600
  type                      = "pki"
}

resource "vault_pki_secret_backend_crl_config" "crl_config_int" {
  depends_on                = [vault_mount.pki_engine_int]
  backend                   = vault_mount.pki_engine_int.path
  expiry                    = "8760h"
  disable                   = false
}

# tls-auth-issuer-role creates a Vault role which will have permissions to issue TLS
# auth certs.
resource "null_resource" "tls-auth-issuer-role" {
  depends_on = [vault_pki_secret_backend_crl_config.crl_config_int]
  provisioner "local-exec" {
    command = <<EOF
            curl \
              --header "X-Vault-Token: ${var.vault_token}" \
              --request POST \
              --data @payload.json \
              ${var.vault_addr}/v1/pki_int/roles/tls-auth-issuer-role
        EOF
  }
}
# # crl_config sets the duration for which the generated cert should be valid.
# resource "vault_pki_secret_backend_crl_config" "crl_config" {
#   depends_on                = ["vault_pki_secret_backend.pki_engine"]
#   backend                   = vault_pki_secret_backend.pki_engine.path
#   expiry                    = "8760h"
#   disable                   = false
# }

# # Create a backend root certificate for our PKI Engine
# resource "vault_pki_secret_backend_root_cert" "root" {
#   depends_on                = ["vault_pki_secret_backend_crl_config.crl_config"]
#   backend                   = vault_pki_secret_backend.pki_engine.path
#   type                      = "internal"
#   common_name               = "Root CA"
#   ttl                       = "315360000"
#   format                    = "pem"
#   private_key_format        = "der"
#   key_type                  = "rsa"
#   key_bits                  = 2048
#   exclude_cn_from_sans      = true
#   ou                        = "My OU"
#   organization              = var.env
# }

# # config_urls sets up the endpoints for the configuration URLs.
# resource "vault_pki_secret_backend_config_urls" "config_urls" {
#   depends_on                = ["vault_pki_secret_backend_crl_config.crl_config"]
#   backend                   = vault_pki_secret_backend.pki_engine.path
#   issuing_certificates      = ["${var.vault_addr}/v1/${vault_pki_secret_backend.pki_engine.path}/ca"]
#   crl_distribution_points   = ["${var.vault_addr}/v1/${vault_pki_secret_backend.pki_engine.path}/crl"]
# }

# # Engine the PKI Intermediate Secret Engine
# resource "vault_pki_secret_backend" "pki_intermediate" {
#   path                      = "pki_int"
#   default_lease_ttl_seconds = 3600
#   max_lease_ttl_seconds     = 43800
# }

# # Generate Intermediate CSR
# resource "vault_pki_secret_backend_intermediate_cert_request" "int_cert" {
#   depends_on = [ "vault_pki_secret_backend.pki_engine" ]
#   backend = vault_pki_secret_backend.pki_engine.path
#   type = "internal"
#   common_name = "${var.env}.com Intermediate Authority"
# }

# # Generate Intermediate Cert Signed by Root
# resource "vault_pki_secret_backend_root_sign_intermediate" "sign_int" {
#   depends_on = [ "vault_pki_secret_backend_intermediate_cert_request.int_cert" ]

#   backend = vault_pki_secret_backend.pki_engine.path
#   csr = vault_pki_secret_backend_intermediate_cert_request.int_cert.csr
#   common_name = "Intermediate CA"
#   exclude_cn_from_sans = true
#   ou = var.env
#   organization = var.env
# }

# resource "vault_pki_secret_backend_intermediate_set_signed" "intermediate" { 
#   backend = vault_pki_secret_backend.pki_intermediate.path
#   certificate = vault_pki_secret_backend_root_sign_intermediate.sign_int.certificate
# }


# # # ca_configuration set's up a certificate authority for Vault that will
# # # issue certificates.
# # resource "vault_pki_secret_backend_config_ca" "ca_configuration" {
# #   depends_on = [vault_pki_secret_backend_crl_config.config_urls]
# #   backend    = vault_pki_secret_backend_crl_config.crl_config.backend
# #   pem_bundle = file("../../../../config/certs/intermediate.cert.pem")
# # }

# # tls-issuer-role creates a Vault role which will have permissions to issue 
# # server certs.
# resource "null_resource" "tls-issuer-role" {
#   depends_on = [vault_pki_secret_backend_config_urls.config_urls]
#   provisioner "local-exec" {
#     command = <<EOF
#             curl \
#               --header "X-Vault-Token: ${var.vault_token}" -k \
#               --request POST \
#               --data @payload.json \
#               ${var.vault_addr}/v1/pki_int/roles/tls-issuer-role
#         EOF
#   }
# }