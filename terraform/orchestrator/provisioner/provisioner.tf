provider "vault" {
  token = var.vault_token
}

# I WOULD REVISIT THIS LATER TO SEE IF IT MAKES SENSE TO SPLIT UP
# CONCERN:
# This creates a token that is used to create, update, delete the secret
# engine settings in vault.  Each of the policies that are being attached
# are created during bootstrap to allow a provisioner token to be generated
# when someting need change.
# I would suggest not having a master anything as it might have
# more permissions than needed at any given time.


# RESPONSE: 
# The reason why this type of token was created is because
# the terraform vault token variable can only be one value at a time.
# Any application that is onboarded with more than one role will cause
# the terraform apply to fail (e.g. mssql roles can be created but
# then ad will fail since the token cannot run that portion).
# This may be mitigated when we offload role creation into a separate
# process. Any thoughts on this? This has been brought up in stand-ups
# before but you may have not been present.

resource "vault_token" "master-provisioner" {
  display_name = "master-provisioner"
  no_parent    = true
  policies = [
    "tls-auth-issuer-role-policy",
    "tls-auth-certificate-issuer-policy",
    "cert-role-issuer-policy",
    "mssql-provisioner-policy",
    "acl-provisioner-policy",
    "ad-provisioner-policy"
  ]
  ttl = "5m"
  #num_uses     = 1
}

output "master_provisioner_token" {
  value     = vault_token.master-provisioner.client_token
  sensitive = true
}

variable "vault_token" {

}
