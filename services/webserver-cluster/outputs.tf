
# Output to command line for convenience. Don't need to make dependency
# Terraform outputs via 'apply' or 'terraform output [var name]'
# No longer applicable for ASG
/*output "public_ip" {
    value = "${aws_instance.example.public_ip}"
}*/
output "availability_zones" {
    value = "${data.aws_availability_zones.all.names}"
}
output "elb_dns_name" {
    value = "${aws_elb.example.dns_name}"
}

# Output to users
output "asg_name" {
    value = "${aws_autoscaling_group.example.name}"
}

# Output for overriding (not done in client) p147
output "aws_security_group_elb_id" {
    value = "${aws_security_group.elb.id}"
}