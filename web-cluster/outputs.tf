#show dns name
output "public_dns" {
        value = "${aws_alb.example.dns_name}"
}
