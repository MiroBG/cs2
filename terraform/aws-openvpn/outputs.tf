output "openvpn_enabled" {
  value = local.openvpn_enabled
}

output "instance_id" {
  value = try(aws_instance.openvpn[0].id, null)
}

output "public_ip" {
  value = try(aws_instance.openvpn[0].public_ip, null)
}

output "public_dns" {
  value = try(aws_instance.openvpn[0].public_dns, null)
}

output "security_group_id" {
  value = try(aws_security_group.openvpn[0].id, null)
}

output "ca_certificate_pem" {
  value     = try(tls_self_signed_cert.ca[0].cert_pem, null)
  sensitive = true
}

output "client_certificate_pem" {
  value     = try(tls_locally_signed_cert.client[0].cert_pem, null)
  sensitive = true
}

output "client_private_key_pem" {
  value     = try(tls_private_key.client[0].private_key_pem, null)
  sensitive = true
}

output "client_ovpn_config" {
  value     = local.client_ovpn_config
  sensitive = true
}