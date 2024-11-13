
# Root level def to support ASG AZs (Availability Zones).  Like an import?
data "aws_availability_zones" "all" {
    state = "available"
}

# Allows for better compatibility and stability
terraform { 
    required_providers { 
        aws = { 
            source = "hashicorp/aws" 
            version = "~> 5.75.0" } 
        } 
        required_version = "~> 1.9.8" 
}

# Workaround due to ASG need for base64encode()
locals {
    user_data_raw = <<-EOF
                #!/bin/bash
                echo "Hello, World" > index.html
                nohup busybox httpd -f -p "${var.server_port}" &
                EOF
}
# *** AWS now wants launch templates instead of launch_configuration
resource "aws_launch_template" "example" {
    name_prefix = "example"
    image_id     = "ami-40d28157"
    instance_type = "t2.nano"
    # Ties to the aws_security_group below. 
    # There is now a dependency between this resource and aws_secuirty_group
    vpc_security_group_ids = ["${aws_security_group.instance.id}"]

    # this is in lieu of a packaged vm deployed to AMI
    # Deploys the web server in this VM instance
    user_data = base64encode("${local.user_data_raw}")

    # This from tags in single server.  Available on any resource.
    # If true, need to set on all dependents, else will error.
    lifecycle {
        create_before_destroy = true
    }
    # added per cp.block_device_mappings 
    tags = {
      Name = "example-launch-template"
    }
}

# Create ASG aws_autoscaling_group to support aws_launch_configuration
resource "aws_autoscaling_group" "example" {
    launch_template {
        id = aws_launch_template.example.id
    }
    availability_zones = "${data.aws_availability_zones.all.names}"

    # Load Balancer and health check
    load_balancers = ["${aws_elb.example.name}"]
    health_check_type = "ELB"

    min_size = 1
    max_size = 1

    tag {
        key = "Name"
        value = "${var.cluster_name}-example"
        propagate_at_launch = true
    }
}

# DEFINE security group for  bi-di traffic to defined ports 
# (default AWS is to disallow all)
resource "aws_security_group" "instance" {
    name = "${var.cluster_name}-instance"

    ingress {
        # from_port = 8080.  Use Variables avoiding DRY.
        # to_port   = 8080.  Use Variables avoiding DRY.
        from_port = "${var.server_port}"
        to_port   = "${var.server_port}"
        protocol  = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    lifecycle {
        create_before_destroy = true
    }
}

# Create ELB (Elastic Load Balancer) with DNS and routing listener
# and health check (will automatically manage unresponsive instances)
resource "aws_elb" "example" {
    name = "${var.cluster_name}-example"
    availability_zones = data.aws_availability_zones.all.names
    security_groups = ["${aws_security_group.elb.id}"]

    listener {
        lb_port = 80
        lb_protocol = "http"
        instance_port = "${var.server_port}"
        instance_protocol = "http"
    }
    # Security group will need egress block for this to take effect
    health_check {
      healthy_threshold = 2
      unhealthy_threshold = 2
      timeout = 3
      interval = 30
      target = "HTTP:${var.server_port}/"
    }
}
# Need new security group for ELB like was done for EC2 instances
# Now need to bind somewhere...
resource "aws_security_group" "elb" {
    name = "${var.cluster_name}-elb"

    # split to separate resources to allow overriding p147
    /*
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    # 0 means all ports, -1 means all protocols
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }*/
}
# Use separate resources for overriding capabilities vs inline when using module
resource "aws_security_group_rule" "allow_http_inbound" {
    type = "ingress"
    security_group_id = "${aws_security_group.elb.id}"

    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
}
resource "aws_security_group_rule" "allow_http_outbound" {
    type = "egress"
    security_group_id = "${aws_security_group.elb.id}"

    from_port = 0
    to_port = 0
    protocol = -1
    cidr_blocks = ["0.0.0.0/0"]
}

