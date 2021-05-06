output "vpc_id" {
  value = aws_vpc.mainvpc.id
}

output "default_nacl" {
  value = aws_default_network_acl.default
}

output "default_rt" {
  value = aws_default_route_table.default
}