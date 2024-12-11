################################################ CONFIG #####################################################

provider "aws" {
  region = "eu-west-2"
}

########################################## FETCH DATA #####################################################

# Fetch the RDS Password from SSM
data "aws_ssm_parameter" "rds_password" {
  name            = "/lamp/rds_password"
  with_decryption = true
}

# Fetch my IP
data "aws_ssm_parameter" "home_ip" {
  name            = "/lamp/home_ip"
  with_decryption = true
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

################################## CREATE IAM SSM ROLE & INSTANCE PROFILE ##################################

# Create IAM Role for EC2
resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2_ssm_role"

  # Attach policy to allow SSM access
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Policy to allow SSM actions
resource "aws_iam_policy" "ec2_ssm_policy" {
  name        = "ec2_ssm_policy"
  description = "Policy allowing EC2 to access SSM"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:DescribeParameters"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# Attach the policy to the role
resource "aws_iam_policy_attachment" "ec2_ssm_attachment" {
  name       = "ec2_ssm_attachment"
  roles      = [aws_iam_role.ec2_ssm_role.name]
  policy_arn = aws_iam_policy.ec2_ssm_policy.arn
}

# Create the Instance Profile
resource "aws_iam_instance_profile" "ec2_ssm_role" {
  name = "ec2_ssm_role_profile"
  role = aws_iam_role.ec2_ssm_role.name
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
    cidr_blocks = ["${data.aws_ssm_parameter.home_ip.value}/32"] # Restrict access to your home IP
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
    cidr_blocks = ["${data.aws_ssm_parameter.home_ip.value}/32"] # Change to specific IP or block
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance for LAMP Stack
resource "aws_instance" "lamp_instance" {
  depends_on        = [aws_db_instance.lamp_db]
  ami               = "ami-0c76bd4bd302b30ec" # Amazon Linux 2 AMI
  instance_type     = "t2.micro"
  key_name          = "main-key"
  security_groups   = [aws_security_group.lamp_sg.name]
  availability_zone = "eu-west-2a" # Adjust as needed

  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_role.name

  user_data = <<-EOF
    #!/bin/bash
    yum update -y

    # Install LAMP stack and Git
    yum install -y httpd php php-mysqlnd mysql git aws-cli
    systemctl start httpd
    systemctl enable httpd

    # Clone the GitHub repository
    cd /var/www/html
    git clone https://github.com/IsaMukadam/LAMP-Stack-App.git .

    # Set file permissions for Apache
    chown -R apache:apache /var/www/html

    # Restart Apache to serve the new code
    systemctl restart httpd
  EOF

  tags = {
    Name = "LAMP-Web-Server"
  }
}

# Amazon RDS for MariaDB Database
resource "aws_db_instance" "lamp_db" {
  allocated_storage      = 20
  storage_type           = "gp2"
  instance_class         = "db.t3.micro"
  availability_zone      = "eu-west-2a"
  engine                 = "mysql" # mysql db
  engine_version         = "8.0"
  username               = "admin"
  password               = data.aws_ssm_parameter.rds_password.value # Fetch password from SSM
  db_name                = "sampledb"
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  multi_az               = false

  tags = {
    Name = "LAMP-MariaDB-DB"
  }
}

# Run MySQL Script to Create a Table and Insert Data
resource "null_resource" "lamp_db_init" {
  depends_on = [aws_db_instance.lamp_db]

  provisioner "local-exec" {
    command = <<EOT
    #!/bin/bash
    while ! mysql -h ${aws_db_instance.lamp_db.endpoint} -u admin -p"${data.aws_ssm_parameter.rds_password.value}" -e "status"; do
      echo "Waiting for MySQL to be ready..."
      sleep 5
    done

    mysql -h ${aws_db_instance.lamp_db.endpoint} -u admin -p"${data.aws_ssm_parameter.rds_password.value}" -e "
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

########################################### CREATE SSM Parameter #############################################

resource "aws_ssm_parameter" "rds_endpoint" {
  name  = "/lamp/rds_endpoint"
  type  = "String"
  value = aws_db_instance.lamp_db.endpoint
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
