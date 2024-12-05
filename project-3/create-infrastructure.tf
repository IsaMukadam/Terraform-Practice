######################## Example Infrastructure Task ####################

provider "aws" {
    region  = "eu-west-2"
}


# 1. Create VPC

resource "aws_vpc" "p3-vpc" {
    cidr_block = "10.0.0.0/16"

    tags = {
      Name = "p3-vpc"
    }
}

# 2. Create IGW

resource "aws_internet_gateway" "p3-igw" {
    vpc_id = aws_vpc.p3-vpc.id

    tags = {
      Name = "p3-igw"
    }
}

# 3. Create Custom Route Table

resource "aws_route_table" "p3-rt" {
    vpc_id = aws_vpc.p3-vpc.id

    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.p3-igw.id
    }

    route {
      ipv6_cidr_block = "::/0"
      gateway_id      = aws_internet_gateway.p3-igw.id
    }

    tags = {
      Name = "project-3-rt"
    }
}

# 4. Create Some Subnets

resource "aws_subnet" "p3-sn1" {
    vpc_id            = aws_vpc.p3-vpc.id
    cidr_block        = "10.0.1.0/24"
    availability_zone = "eu-west-2a"

    tags = {
      Name = "project-3-sn1"
    }
}

# 5. Associate Subnets with Route Table

resource "aws_route_table_association" "p3-sn1-to-rt" {
    subnet_id      = aws_subnet.p3-sn1.id
    route_table_id = aws_route_table.p3-rt.id
}

# 6. Create SG to allow Port 22, 80 and 443

resource "aws_security_group" "p3-sg-allow-web" {
    name        = "allow_web_traffic"
    description = "Allow web traffic"
    vpc_id      = aws_vpc.p3-vpc.id

    ingress {
      description = "HTTPS"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
      description = "HTTP"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
      description = "SSH"
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

    tags = {
      Name = "allow_web_traffic"
    }
}

# 7. Create an NI with an IP in the subnet created in 4.

resource "aws_network_interface" "p3-web-server-nic" {
    subnet_id       = aws_subnet.p3-sn1.id
    private_ips     = ["10.0.1.50"]
    security_groups = [aws_security_group.p3-sg-allow-web.id]
}

# 8. Assign an Elastic IP to NI created in 7.

resource "aws_eip" "one" {
    depends_on                = [aws_internet_gateway.p3-igw]
    network_interface         = aws_network_interface.p3-web-server-nic.id
    domain                    = "vpc"
    associate_with_private_ip = "10.0.1.50"
}

# 9. Create Ubuntu Server and Install & Enable Apache2

resource "aws_instance" "p3-web-server-instance" {
    ami               = "ami-0e8d228ad90af673b"
    instance_type     = "t2.micro"
    availability_zone = "eu-west-2a"
    key_name          = "main-key"

    network_interface {
      device_index         = 0
      network_interface_id = aws_network_interface.p3-web-server-nic.id
    }

    user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo web server example > /var/www/html/index.html
                EOF

    tags = {
      Name = "p3 Ubuntu Web Server"
    }
}

#########################################################################

