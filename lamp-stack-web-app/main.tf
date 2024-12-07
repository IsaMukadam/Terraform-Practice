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

# Security Group for the Web Server (EC2)
resource "aws_security_group" "lamp_sg" {
  name_prefix = "lamp-sg"

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS Security Group (Allow MySQL Access Only from EC2 Instance and Specific IP)
resource "aws_security_group" "rds_sg" {
  name_prefix = "rds-sg"

  ingress {
    description     = "Allow MySQL Access from EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.lamp_sg.id] # Allow traffic only from EC2 instance
  }

  ingress {
    description = "Allow MySQL Access from Specific IP"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["your-ip-address/32"] # Replace with your IP address
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance for LAMP Stack (Apache, PHP, GitHub code pull)
resource "aws_instance" "lamp_instance" {
  ami               = "ami-0c76bd4bd302b30ec" # Amazon Linux 2 AMI
  instance_type     = "t2.micro"
  key_name          = "main-key"
  security_groups   = [aws_security_group.lamp_sg.name]
  availability_zone = "eu-west-2a" # Adjust to your desired AZ

  user_data = <<-EOF
    #!/bin/bash
    yum update -y

    # Install Apache, PHP, Git, MySQL client
    yum install -y httpd php php-mysqlnd mysql git
    systemctl start httpd
    systemctl enable httpd

    # Clone the GitHub repository with the website code
    cd /var/www/html
    git clone https://github.com/your-github-username/your-repository.git .
    
    # Set file permissions for Apache to serve the site
    chown -R apache:apache /var/www/html

    # Restart Apache to serve the new code
    systemctl restart httpd
  EOF

  tags = {
    Name = "LAMP-Web-Server"
  }
}

# Amazon RDS for MySQL Database
resource "aws_db_instance" "lamp_db" {
  allocated_storage      = 20
  storage_type           = "gp2"
  instance_class         = "db.t2.micro"
  engine                 = "mysql"
  engine_version         = "8.0"
  username               = "admin"
  password               = "your-password" # Consider using Secrets Manager for security
  db_name                = "sampledb"
  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  multi_az               = false

  tags = {
    Name = "LAMP-MySQL-DB"
  }
}

# Run MySQL Script to Create a Table and Insert Data
resource "null_resource" "lamp_db_init" {
  depends_on = [aws_db_instance.lamp_db]

  provisioner "local-exec" {
    command = <<EOT
      mysql -h ${aws_db_instance.lamp_db.endpoint} -u admin -p${aws_db_instance.lamp_db.password} -e "
      CREATE DATABASE IF NOT EXISTS sampledb;
      USE sampledb;
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100),
        email VARCHAR(100)
      );
      INSERT INTO users (name, email) VALUES
      ('John Doe', 'john@example.com'),
      ('Jane Doe', 'jane@example.com'),
      ('Alice Smith', 'alice@example.com');
    "
    EOT
  }
}

################################################ OUTPUTS #####################################################

# Output the Public IP of the EC2 Instance (Web Server)
output "lamp_server_ip" {
  value = aws_instance.lamp_instance.public_ip
}

# Output the RDS Endpoint (Database)
output "lamp_db_endpoint" {
  value = aws_db_instance.lamp_db.endpoint
}

################################################ ROUTE53 DNS #####################################################

# Route 53 Record for DNS (optional)
# resource "aws_route53_record" "dns" {
#     zone_id = "Z1234567890" # Replace with hosted zone ID
#     name = "www.exampledomain.com"
#     type = "A"
#     ttl = 300
#     records = [aws_instance.web_server.public_ip]
# }
