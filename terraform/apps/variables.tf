variable "datacenter" {
  description = "Key that indicates which datacenter we're targeting."
  default     = "local"
}

variable "datacenter_environment" {
  description = "Typically lower/prod/sandbox. Indicates which environment we're targeting"
  default     = "Mimir"
}

variable "token" {
  description = "Token required for authenticating with Vault"
}
