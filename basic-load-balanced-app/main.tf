provider "aws" {
  region = "eu-west-2" # Set region to EU West (London)
}

# Create a new VPC
resource "aws_vpc" "web_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Create Subnet 1 in Availability Zone 1 (eu-west-2a)
resource "aws_subnet" "web_subnet_1" {
  vpc_id                  = aws_vpc.web_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = true
}

# Create Subnet 2 in Availability Zone 2 (eu-west-2b)
resource "aws_subnet" "web_subnet_2" {
  vpc_id                  = aws_vpc.web_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-west-2b"
  map_public_ip_on_launch = true
}

# Create an Internet Gateway to allow internet access
resource "aws_internet_gateway" "web_igw" {
  vpc_id = aws_vpc.web_vpc.id
}

# Create Route Table to route traffic from subnets to the Internet
resource "aws_route_table" "web_rt" {
  vpc_id = aws_vpc.web_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.web_igw.id
  }
}

# Associate Route Table with Subnets
resource "aws_route_table_association" "subnet_1_association" {
  subnet_id      = aws_subnet.web_subnet_1.id
  route_table_id = aws_route_table.web_rt.id
}

resource "aws_route_table_association" "subnet_2_association" {
  subnet_id      = aws_subnet.web_subnet_2.id
  route_table_id = aws_route_table.web_rt.id
}

# Security Group for EC2 instances (allow SSH and HTTP)
resource "aws_security_group" "web_sg" {
  name_prefix = "web_sg"
  vpc_id      = aws_vpc.web_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for Load Balancer (allow HTTP)
resource "aws_security_group" "lb_sg" {
  name_prefix = "lb_sg"
  vpc_id      = aws_vpc.web_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create EC2 Instances in the Subnets (for Load Balancing)
resource "aws_instance" "web" {
  ami                    = "ami-05c172c7f0d3aed00" # Ubuntu AMI in EU West (London)
  instance_type          = "t2.micro"
  key_name               = "main-key" # Replace with your key name
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  subnet_id              = element([aws_subnet.web_subnet_1.id, aws_subnet.web_subnet_2.id], count.index) # Distribute across both subnets # Launch in the first subnet
  count                  = 2                                                                              # Create 2 EC2 instances for load balancing

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y apache2 python3 python3-pip

    # Install mod_wsgi for Apache
    apt-get install -y libapache2-mod-wsgi-py3
    apt-get update

    # Install Flask
    apt install -y python3-flask 

    # Create Flask application
    cat <<EOT > /var/www/html/app.py
    from flask import Flask
    app = Flask(__name__)

    @app.route('/')
    def hello_world():
        return "Hello, Basic Python Flask App"

    application=app

    if __name__ == '__main__':
        app.run(host='0.0.0.0')
    EOT

    # Configure Apache to serve the Flask app via mod_wsgi
    cat <<EOT > /etc/apache2/sites-available/000-default.conf
    <VirtualHost *:80>
        ServerName localhost

        WSGIDaemonProcess flaskapp user=www-data group=www-data threads=5
        WSGIScriptAlias / /var/www/html/app.py

        <Directory /var/www/html>
            WSGIProcessGroup flaskapp
            WSGIApplicationGroup "GLOBAL"
            Require all granted
        </Directory>
    </VirtualHost>
    EOT

    # Enable the mod_wsgi module and restart Apache
    a2enmod wsgi
    systemctl restart apache2
    systemctl enable apache2
  EOF

  tags = {
    Name = "Basic-Python-Flask-App-With-LB"
  }
}

# Create Application Load Balancer
resource "aws_lb" "web_lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.web_subnet_1.id, aws_subnet.web_subnet_2.id]

  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "Web Load Balancer"
  }
}

# Create Load Balancer Target Group for EC2 instances
resource "aws_lb_target_group" "web_tg" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.web_vpc.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
}

# Create Listener for Load Balancer to forward HTTP traffic
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      status_code  = 200
      content_type = "text/plain"
      message_body = "Healthy"
    }
  }
}

# Attach EC2 Instances to the Load Balancer Target Group
resource "aws_lb_target_group_attachment" "web_tg_attachment" {
  count            = 2 # Attach both EC2 instances
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}
