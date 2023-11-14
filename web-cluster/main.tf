
data "aws_availability_zones" "all" {

}

#test branch v.0.0.2
resource "aws_launch_configuration" "example" {
	image_id = var.ami #"ami-40d28157"
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
	name_prefix = "${var.cluster_name}-tf1-example-instance"
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
  name_prefix = "${var.cluster_name}-SSHSecurityGroup"
  description = "Allow SSH access v.0.0.2"
  
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

data "aws_vpc" "default"{
	#filterout default vpc
	default = true
}

data "aws_subnet_ids" "default"{
	vpc_id = data.aws_vpc.default.ids[0]
}

#create (A)uto(S)caling(G)roup ALB edition
resource "aws_autoscaling_group" "example" {
	#get linked launch config with resource ubuntu
	launch_configuration = "${aws_launch_configuration.example.id}"
	#give a name to ASG
	name = "${var.cluster_name}-${aws_launch_configuration.example.name}"
        
	#list all zones
	availability_zones = ["${data.aws_availability_zones.all.names[0]}","${data.aws_availability_zones.all.names[1]}"]
	
	#elb amazon elastic load balancer -not needed in alb case
	#load_balancers = ["${aws_elb.example.name}"]

	#alb config has target_group_arns
	target_group_arns = [aws_lb_target_group.asg.arn]
	health_check_type = "ELB" #use target group health_check

	#instances range min max for autoscaling
	min_size = var.min_size
	max_size = var.max_size
	#when change wait for new instances created befoere destroy old
	min_elb_capacity = var.min_size

	tag {
		key = "${var.cluster_name}-ASG"
		value = "${var.cluster_name}-tf-asg-example"
		propagate_at_launch = true
	}
	#create changed then destroy zero downtime policy
	#should be switched as well on all dependant things elb sg etc
	lifecycle {
	  create_before_destroy = true
	}
	#set vpc_zone_identifier - set with default subnets
	vpc_zone_identifier = data.aws_subnet_ids.default.ids
	
} 

#App load balanceer
resource "aws_lb" "example"{
	name = "${var.cluster_name}-tf-alb-example"
	load_balancer_type = "application"
	#use all subnets for lb
	subnets = data.aws_subnet_ids.default.ids
	#set security group to allow incoming connex for listener 80:HTTP
	security_groups = [aws_security_group.elb.id]]
}

#App l-b listener
resource "aws_lb_listener" "http"{
	#unique arn of balancer
	load_balancer_arn = aws_lb.example.arn
	port		  = 80 #listen on
	protocol 	  = "HTTP"

	# default action for Not LISTENER MATCH RULE - give 404 reply
	default_action {
		type = "fixed-response"
		fixed_response{
			content_type = "text/plain"
			message_body = "404: not found"
			status_code = 404"
		}
	}
	
	lifecycle {
          create_before_destroy = true
        }
}

#App l-b listener_rule like route path in urls.py django
resource "aws_lb_listener_rule" "asg" {
	#unique arn of listener
	listener_arn = aws_lb_listener.http.arn
	#set prio
	priority = 100

	#search in path this case for - anything
	condition {
	   field = "path-pattern"
	   values  = ["*"]
	}

	#
	action {
	   type  = "forward"
	   #forward to as per target group resource	
	   target_group_arn = aws_lb_target_group.asg.arn
	}

	lifecycle {
          create_before_destroy = true
        }
}

#App l-b target_group
resource "aws_lb_target_group" "asg" {
	name = "${var.cluster_name}-tf-alb_target_group-example"

	port 	 = var.s_port
	protocol = "HTTP"

	vpc_id   = data.aws_vpc.default.id
	
	health_check {
	  #checks instances to be alive
	  #if instance doesnot response its removed from group to which elb 
	  #redirects incoming user traffic
          healthy_threshold = 2
          unhealthy_threshold = 2
          timeout = 3
          interval = 20
	  path		= "/"
	  protocol 	= "HTTP"
	  matcher	= "200"
	}

	lifecycle {
          create_before_destroy = true
        }
}



#ELB
#resource "aws_elb" "example" {
#	name = "${var.cluster_name}-tf-elb-example"
#        availability_zones = ["${data.aws_availability_zones.all.names[0]}","${data.aws_availability_zones.all.names[1]}"]
	
#	listener { #redir 80->8081 (http)
#		lb_port       = 80
#		lb_protocol   = "http"
#		instance_port = "${var.s_port}"
#		instance_protocol = "http"
#	}
	
#	health_check {
#		healthy_threshold = 2
#		unhealthy_threshold = 2
#		timeout = 3
#		interval = 30
#		target = "HTTP:${var.s_port}/"
#	}
#	
#	lifecycle {
#          create_before_destroy = true
#        }

#}

#ELB sec_group to allow 80 port
resource "aws_security_group" "elb" {
  name_prefix = "${var.cluster_name}-ELBSecurityGroup"
  description = "Allow 80 for ELB access."
	
  lifecycle {
        create_before_destroy = true
  }
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
    	protocol    = "-1" #ANY
    	cidr_blocks = ["0.0.0.0/0"] #ANY 

}

#backend S3 get some data from RDS Mysql instance
data "terraform_remote_state" "db" {
	backend = "s3"
	config = {
		bucket = var.db_remote_state_bucket
		key = var.db_remote_state_bucket_key
		region = var.aws_region
	}
}

#user_data as data record
data "template_file" "user_data" {
	template = "${file("${path.module}/user-data.sh")}"
	vars = {
		s_port = "${var.s_port}"
		dbaddress = "${data.terraform_remote_state.db.outputs.dbaddress}"
		dbport = "${data.terraform_remote_state.db.outputs.dbport}"
		servertext = var.servertext
	}
}

#output "public_dns" {
#	value = "${aws_elb.example.dns_name}"
#}

