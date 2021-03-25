# https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/transform_role
# Mount the engine
resource "vault_mount" "transform_mount" {
  path = "transform"
  type = "transform"
}

# Define a new library for use in a transformation
resource "vault_transform_alphabet" "numerics_alpha" {
  path = vault_mount.transform_mount.path
  name = "numerics"
  alphabet = "0123456789"
}

# Define a template for the transformation
resource "vault_transform_template" "ccn_template" {
  path = vault_transform_alphabet.numerics_alpha.path
  name = "ccn"
  type = "regex"
  pattern = "(\\d{4})-(\\d{4})-(\\d{4})-(\\d{4})"
  alphabet = "numerics"
}

# Preform a transformation
resource "vault_transform_transformation" "ccn_transform" {
  path = vault_mount.transform_mount.path
  name = "ccn-fpe"
  type = "fpe"
  template = "ccn"
  tweak_source = "internal"
  allowed_roles = ["payments"]
}

# Create a role for using transformations
resource "vault_transform_role" "payments_role" {
  path = vault_mount.transform_mount.path
  name = "payments"
  transformations = ["ccn-fpe"]
}