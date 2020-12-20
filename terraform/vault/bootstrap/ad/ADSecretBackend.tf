#This is enabling the AD secrets backend.

resource "null_resource" "ad_secrets_enable" {

  provisioner "local-exec" {
    command = <<EOF
            export VAULT_ADDR=${var.vault_addr};
            export VAULT_TOKEN=${var.vault_token};

            vault secrets enable ad;

            vault write ad/config \
                binddn="${var.ad_binddn}" \
                bindpass="${var.ad_bindpass}" \
                url="${var.ad_url}" \
                userdn="${var.ad_userdn}" \
                tls_min_version="${var.ad_tlsminversion}"
        EOF
  }

}
