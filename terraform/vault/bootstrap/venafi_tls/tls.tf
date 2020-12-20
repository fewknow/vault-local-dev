# USE FOR LOCAL DEVELOPMENT ONLY
# resource "vault_pki_secret_backend_root_cert" "root" {
#   depends_on = ["vault_pki_secret_backend_crl_config.crl_config"]

#   backend = "tls"

#   type                 = "internal"
#   common_name          = "qvc.com"
#   ttl                  = "87600h"
#   format               = "pem"
#   private_key_format   = "der"
#   key_type             = "rsa"
#   key_bits             = 4096
#   exclude_cn_from_sans = true
#   ou                   = "My OU"
#   organization         = "QVC"
# }

# # crl_config sets the duration for which the generated cert should be valid.
# resource "vault_pki_secret_backend_crl_config" "crl_config" {
#   depends_on = [null_resource.enable_tls_engine]
#   backend    = "tls"
#   expiry     = "8760h"
#   disable    = false
# }

# # ca_configuration set's up a certificate authority for Vault that will
# # issue certificates.
# resource "vault_pki_secret_backend_config_ca" "ca_configuration" {
#   depends_on = [vault_pki_secret_backend_crl_config.crl_config]
#   backend    = vault_pki_secret_backend_crl_config.crl_config.backend
#   pem_bundle = file("./bundle-ca.pem")
# }

# # config_urls sets up the endpoints for the configuration URLs.
# resource "vault_pki_secret_backend_config_urls" "config_urls" {
#   depends_on              = [vault_pki_secret_backend_config_ca.ca_configuration]
#   backend                 = "tls"
#   issuing_certificates    = ["${var.vault_addr}/v1/tls/ca"]
#   crl_distribution_points = ["${var.vault_addr}/v1/tls/crl"]
# }

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
#               ${var.vault_addr}/v1/tls/roles/tls-issuer-role
#         EOF
#   }
# }

# # enable_tls_engine enables the tls backend with the Venafi monitor plugin and
# # creates a venafi-policy that binds to a Vault policy to allow for Venafi policy
# # enforcement.
# resource "null_resource" "enable_tls_engine" {
#   provisioner "local-exec" {
#     command = <<EOF
#             export VAULT_ADDR=${var.vault_addr};
#             export VAULT_TOKEN=${var.vault_token};

#             vault secrets enable -path=tls -plugin-name=vault-pki-monitor-venafi_strict plugin;
#             vault write tls/venafi-policy/${var.venafi_policy_name} \
#                 tpp_url="${var.venafi_address}" \
#                 tpp_user="${var.venafi_user}" \
#                 tpp_password="${var.venafi_password}" \
#                 zone="${var.venafi_policy_zone_tls}" \
#                 trust_bundle_file="${var.venafi_certificate_path}";
#         EOF
#   }
# }
