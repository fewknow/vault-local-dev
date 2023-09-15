backend "consul" {
   address = "consul:8500"
   advertise_addr = "http://consul:8300"
   scheme = "http"
}

listener "tcp" {
    address = "0.0.0.0:8200"
    tls_cert_file = "/config/cluster_certs/localhost.crt"
    tls_key_file = "/config/cluster_certs/localhost.key"
}

# seal "awskms" {
#   region = "us-west-2"
#   kms_key_id = "f09629d2-2f63-432c-a10d-4c29b30b7a0e"
# }

api_addr = "https://localhost:8200"
disable_mlock = true
ui=true
plugin_directory = "vault/venafi"