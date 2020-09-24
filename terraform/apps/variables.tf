variable "datacenter" {
  description = "Key that indicates which datacenter we're targeting."
}

variable "datacenter_environment" {
  description = "Typically lower/prod/sandbox. Indicates which environment we're targeting"
}

variable "token" {
  description = "Token required for authenticating with Vault"
}

variable "policy_location" {
  description = "Path to the policy.json file to be read in and applied"
}
