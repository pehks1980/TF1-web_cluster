
data "aws_availability_zones" "all" {

}

#provider "aws" { #not in module
#  region = "us-east-1"
#}

#variable "s_port" {
#	description = "server listen port (http)"
#	default = "8081"
#}

resource "aws_launch_configuration" "example" {
	image_id = "ami-40d28157"
	instance_type = var.instance_type

	security_groups = ["${aws_security_group.instance.id}","${aws_security_group.ssh.id}","${aws_security_group.elb.id}"]

	key_name  = "myec2key"
	
	user_data = "${data.template_file.user_data.rendered}"

	#user_data = <<-EOF
	#	#!/bin/bash
	#	echo "Hello World" > index.html
	#	nohup busybox httpd -f -p "${var.s_port}" &
	#	EOF

	lifecycle {
		create_before_destroy = true
	}
}	

resource "aws_security_group" "instance" {
	name = "${var.cluster_name}-tf1-example-instance"
	ingress {
		from_port = "${var.s_port}"
		to_port = "${var.s_port}"
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"] #any IP allowed
	}

	lifecycle {
		create_before_destroy = true
	}
	
}

resource "aws_security_group" "ssh" {
  name        = "${var.cluster_name}-SSHSecurityGroup"
  description = "Allow SSH access"
  
  	ingress {
    		from_port   = 22
    		to_port     = 22
    		protocol    = "tcp"
    		cidr_blocks = ["0.0.0.0/0"] # You can restrict this to your specific IP range for better security
 	}

	lifecycle {
		create_before_destroy = true
	}
}

#create (A)uto(S)caling(G)roup
resource "aws_autoscaling_group" "example" {
	#get linked launch config with resource ubuntu
	launch_configuration = "${aws_launch_configuration.example.id}"
        #list all zones
	availability_zones = ["${data.aws_availability_zones.all.names[0]}","${data.aws_availability_zones.all.names[1]}"]
	#elb
	load_balancers = ["${aws_elb.example.name}"]
	health_check_type = "ELB"

	#instances range min max for autoscaling
	min_size = var.min_size
	max_size = var.max_size

	tag {
		key = "${var.cluster_name}-ASG"
		value = "${var.cluster_name}-tf-asg-example"
		propagate_at_launch = true
	}
} 

#ELB
resource "aws_elb" "example" {
	name = "${var.cluster_name}-tf-elb-example"
        availability_zones = ["${data.aws_availability_zones.all.names[0]}","${data.aws_availability_zones.all.names[1]}"]
	
	listener { #redir 80->8081 (http)
		lb_port       = 80
		lb_protocol   = "http"
		instance_port = "${var.s_port}"
		instance_protocol = "http"
	}
	
	health_check {
		healthy_threshold = 2
		unhealthy_threshold = 2
		timeout = 3
		interval = 30
		target = "HTTP:${var.s_port}/"
	}

}

#ELB sec_group to allow 80 port
resource "aws_security_group" "elb" {
  name        = "${var.cluster_name}-ELBSecurityGroup"
  description = "Allow 80 for ELB access"
}

resource "aws_security_group_rule" "allow_http_in" { 
  	type = "ingress" 
	security_group_id = "${aws_security_group.elb.id}"
    		
	from_port   = 80
    	to_port     = 80
    	protocol    = "tcp"
    	cidr_blocks = ["0.0.0.0/0"] # You can restrict this to your specific IP range for better security
}

resource "aws_security_group_rule" "allow_all_out" {  
	
	security_group_id = "${aws_security_group.elb.id}"
    		
	type = "egress" 
	
	from_port   = 0
    	to_port     = 0
    	protocol    = "-1"
    	cidr_blocks = ["0.0.0.0/0"] 

}

#backend S3 get some data from RDS Mysql instance
data "terraform_remote_state" "db" {
	backend = "s3"
	config = {
		bucket = var.db_remote_state_bucket
		key = var.db_remote_state_bucket_key
		region = "us-east-1"
	}
}

#user_data as data record
data "template_file" "user_data" {
	template = "${file("${path.module}/user-data.sh")}"
	vars = {
		s_port = "${var.s_port}"
		dbaddress = "${data.terraform_remote_state.db.outputs.dbaddress}"
		dbport = "${data.terraform_remote_state.db.outputs.dbport}"
	}
}

#output "public_dns" {
#	value = "${aws_elb.example.dns_name}"
#}

