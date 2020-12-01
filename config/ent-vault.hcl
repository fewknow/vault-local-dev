disable_performance_standby = true
disable_mlock = true
ui = true
api_addr = "https://localhost:8200"

backend "consul" {
   address = "consul:8500"
   advertise_addr = "http://consul:8300"
   scheme = "http"
}

listener "tcp" {
 address     = "0.0.0.0:8200"
 tls_disable = 0
 tls_cert_file = "/config/cluster_certs/localhost.crt"
 tls_key_file = "/config/cluster_certs/localhost.key"
}

seal "awskms" {
  region     = "us-west-2"
  kms_key_id = "f094181b-9097-4ca1-9935-c89f8a196fea"
}  
