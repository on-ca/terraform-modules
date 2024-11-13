

variable "server_port" {
    description="The port the server will use for HTTP requests"
    type=string # Terraform default, however define while learning
    # no default so Terraform will prompt user.  Just define default...
    default = 8080
}

# Use inputs to have separate namespaces for each user.
# Was "terraform-asg"
variable "cluster_name" {
    description = "The nae to use for all the cluster resources"
}

variable "db_remote_state_bucket" {
    description = "The name of the s3 bucket for the database's remote state"
}

variable "db_remote_state_key" {
    description = "The path for the database's remote stase in S3"
}

# Can add variables for any other config settings e.g. instance_type, min_size,
# max_size.check "

