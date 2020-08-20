terraform {
  backend "artifactory" {
    url  = "https://artifactory.qvcdev.qvc.net/artifactory"
    repo = "terraform-states"
  }
}

variable "username" {
  description = "Artifactory service account username"
}
variable "url" {
  description = "Artifactory url"
}
variable "password" {
  description = "Artifactory service account password"
}
variable "repo" {
  description = "Artifactory repository for tfstate files"
}
