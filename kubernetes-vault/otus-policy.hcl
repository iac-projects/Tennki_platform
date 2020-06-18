path "otus/otus-ro/*" { 
capabilities = ["read", "list"] }

path "otus/otus-rw/*" {
capabilities = ["read", "update", "create", "list"]
}

path "pki_int*" {
capabilities = ["read", "update", "create", "list", "sudo", "delete"]
}

path "pki*" {
capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}