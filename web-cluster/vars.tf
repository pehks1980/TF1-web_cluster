#declare only vars used in module
#init em in stage /prod fodler in module section
variable "cluster_name" {
  description = "The name to use for all the cluster resources"
  type        = string
}

variable "db_remote_state_bucket" {
  description = "The name of the S3 bucket for the database's remote state"
  type        = string
}

variable "db_remote_state_bucket_key" {
  description = "The path for the database's remote state in S3"
  type        = string
}

variable "instance_type" {
  description = "The type of EC2 Instances to run (e.g. t2.micro)"
  type        = string
}

variable "min_size" {
  description = "The minimum number of EC2 Instances in the ASG"
  type        = number
}

variable "max_size" {
  description = "The maximum number of EC2 Instances in the ASG"
  type        = number
}

variable "ami" {
  description = "Ami image name"
  type 		= string
}

variable "aws_region" {
  description = "aws region for s3 config"
  type 		= string
}

variable "servertext" {
  description = "text to server"
  type          = string
}

variable "s_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 8081
}

