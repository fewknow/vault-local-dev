# Policy to allow read access

resource "consul_acl_policy" "full_read_only" {
  name        = "full-read-only"
  datacenters = ["dc1"]
  rules       = <<-RULE
    key_prefix "" {
      policy = "read"
    }
    key_prefix "vault/" {
      policy = "deny"
    }
    node_prefix "" {
      policy = "read"
    }
    service_prefix "" {
      policy = "read"
    }
    session_prefix "" {
      policy = "read"
    }
    RULE
}

# policy to allow writing to consul.

resource "consul_acl_policy" "kv_write" {
  name  = "kv-write"
  rules = <<-RULE
    key_prefix "" {
      policy = "write"
    }
    node_prefix "" {
      policy = "read"
    }
    service_prefix "" {
      policy = "read"
    }
    RULE
}

# policy for the consul agents
resource "consul_acl_policy" "agents" {
  name  = "agents-policy"
  rules = <<-RULE
    key_prefix "" {
      policy = "write"
    }
    node_prefix "" {
      policy = "write"
    }
    service_prefix "" {
      policy = "write"
    }
    session_prefix "" {
      policy = "write"
    }
    RULE
}

# policy for consul servers
resource "consul_acl_policy" "servers" {
  name  = "servers-policy"
  rules = <<-RULE
    key_prefix "" {
      policy = "write"
    }
    node_prefix "" {
      policy = "write"
    }
    service_prefix "" {
      policy = "write"
    }
    session_prefix "" {
      policy = "write"
    }
    RULE
}

# policy to all for backup script to run
resource "consul_acl_policy" "snapshot" {
  name  = "snapshot-policy"
  rules = <<-RULE
    acl = "write"
    key_prefix "" {
      policy = "write"
    }
    node_prefix "" {
      policy = "write"
    }
    service_prefix "" {
      policy = "write"
    }
    session_prefix "" {
      policy = "write"
    }
    RULE
}
