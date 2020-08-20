# USE FOR LOCAL DEVELOPMENT ONLY
# resource "vault_pki_secret_backend_root_cert" "root" {
#   depends_on = ["vault_pki_secret_backend_crl_config.crl_config"]

#   backend = "pki"

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

# crl_config sets the duration for which the generated cert should be valid.
resource "vault_pki_secret_backend_crl_config" "crl_config" {
  depends_on = ["null_resource.enable_tls_auth"]
  backend    = "tls-auth"
  expiry     = "8760h"
  disable    = false
}

# ca-configuration set's up a certificate authority for Vault that will
# issue certificates.
resource "vault_pki_secret_backend_config_ca" "ca-configuration" {
  depends_on = ["vault_pki_secret_backend_crl_config.crl_config"]
  backend    = vault_pki_secret_backend_crl_config.crl_config.backend
  pem_bundle = file("./bundle-ca.pem")
}

# config_urls sets up the endpoints for the configuration URLs.
resource "vault_pki_secret_backend_config_urls" "config_urls" {
  depends_on              = ["vault_pki_secret_backend_config_ca.ca-configuration"]
  backend                 = "tls-auth"
  issuing_certificates    = ["${var.vault_addr}/v1/tls-auth/ca"]
  crl_distribution_points = ["${var.vault_addr}/v1/tls-auth/crl"]
}

# tls-auth-issuer-role creates a Vault role which will have permissions to issue TLS
# auth certs.
resource "null_resource" "tls-auth-issuer-role" {
  depends_on = ["vault_pki_secret_backend_config_urls.config_urls"]
  provisioner "local-exec" {
    command = <<EOF
            curl \
              --header "X-Vault-Token: ${var.vault_token}" \
              --request POST \
              --data @payload.json \
              ${var.vault_addr}/v1/tls-auth/roles/tls-auth-issuer-role
        EOF
  }
}

# enable_tls_auth enables the tls-auth backend with the Venafi monitor plugin to
# create a venafi-policy that binds to a Vault policy to allow Venafi policy
# enforcement.
resource "null_resource" "enable_tls_auth" {
  triggers = {
    vault_addr  = var.vault_addr
    vault_token = var.vault_token
  }
  provisioner "local-exec" {
    command = <<EOF
            export VAULT_ADDR=${var.vault_addr};
            export VAULT_TOKEN=${var.vault_token};

            vault secrets enable -path=tls-auth -plugin-name=vault-pki-monitor-venafi_strict plugin;

            vault write tls-auth/venafi-policy/${var.venafi_policy_name} \
                tpp_url="${var.venafi_address}" \
                tpp_user="${var.venafi_user}" \
                tpp_password="${var.venafi_password}" \
                zone="${var.venafi_policy_zone_tls_auth}" \
                trust_bundle_file="${var.venafi_certificate_path}"
        EOF
  }

  # TODO: We need to add a destory block for any backends that use local-exec.
  # provisioner "local-exec" {
  #   when = destroy
  #   command = <<EOF

  #           export VAULT_ADDR=${self.vault_addr};
  #           export VAULT_TOKEN=${self.vault_token};

  #           vault delete pki/venafi-policy/App-Test
  #           vault delete pki/roles/tls-auth-issuer-role
  #           vault disable -path=pki -plugin-name=vault-pki-monitor-venafi_strict plugin;

  #       EOF
  # }
}
