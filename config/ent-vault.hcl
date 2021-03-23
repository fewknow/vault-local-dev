disable_performance_standby = true
disable_mlock = true
ui = true
api_addr = "https://localhost:8200"
cluster_addr = "http://localhost:8200"

storage "raft" {
  path = "/etc/vault.d/data"
  node_id = "raft_node_1"
}

listener "tcp" {
 address     = "0.0.0.0:8200"
 tls_disable = 0
 tls_cert_file = "/config/cluster_certs/localhost.crt"
 tls_key_file = "/config/cluster_certs/localhost.key"
}

seal "awskms" {
  region     = "us-west-2"
  kms_key_id = "332dfb18-7691-496b-aa52-577ca28f0764"
}  
