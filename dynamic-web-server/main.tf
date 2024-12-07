################################################ CONFIG #####################################################

provider "aws" {
  region = "eu-west-2"
}

# Get the default VPC in the region
data "aws_vpc" "default" {
  default = true
}

# Get a default subnet
data "aws_subnet" "default" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "eu-west-2a"
}

########################################## EC2 INSTANCE SETUP ##############################################

# EC2 Instance (t2.micro) for the Web Server
resource "aws_instance" "web_server" {
  ami               = "ami-0e8d228ad90af673b"
  instance_type     = "t2.micro"
  availability_zone = "eu-west-2a"
  key_name          = "main-key"

  tags = {
    Name = "StaticContentWebServer"
  }

  # Security Group to allow port 80 (HTTP) and port 22 (SSH) access
  security_groups = [aws_security_group.web_sg.name]

  # Auto install web server
  user_data = <<-EOF
                #!/bin/bash
                yum update -y
                yum install -y httpd
                service httpd start
                chkconfig httpd on
                EOF
}

# Setting up Security Group for the EC2 Instance
resource "aws_security_group" "web_sg" {
  name_prefix = "web-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "HTTP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "SSH"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

##################### DYNAMODB DATABASE - NOT NEEDED (For dynamic content storage only) #########################

# # Creating RDS Instance (db.t2.micro) for the Database
# resource "aws_db_instance" "db" {
#     identifier = "dynamodb"
#     engine = "mysql"
#     instance_class = "db.t2.micro"
#     allocated_storage = 20
#     username = "admin"
#     password = "testpass17896@"
#     db_name = "dynamicdb"
#     multi_az = false
#     storage_type = "gp2"
#     backup_retention_period = 7
#     publicly_accessible = true

#     tags = {
#       Name = "DynamoDatabase"
#     }
# }

################################################ ROUTE53 DNS #####################################################

# Route 53 Record for DNS (optional)
# resource "aws_route53_record" "dns" {
#     zone_id = "Z1234567890" # Replace with hosted zone ID
#     name = "www.exampledomain.com"
#     type = "A"
#     ttl = 300
#     records = [aws_instance.web_server.public_ip]
# }

################################################ OUTPUTS #####################################################

#Outputs
output "web_ip" {
  value = aws_instance.web_server.public_ip
}

# output "db_endpoint" {
#   value = aws_db_instance.db.endpoint
# }

