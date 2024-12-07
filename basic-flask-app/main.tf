provider "aws" {
  region = "eu-west-2"
}

# Security Group To Allow Port 80 and 22 Access
resource "aws_security_group" "basic_flask_app_sg" {
  name_prefix = "basic_flask_app_sg"

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

# EC2 Instance
resource "aws_instance" "basic_flask_app" {
  ami               = "ami-0c76bd4bd302b30ec"
  instance_type     = "t2.micro"
  key_name          = "main-key"
  availability_zone = "eu-west-2a"
  security_groups   = [aws_security_group.basic_flask_app_sg.name]

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd python3 python3-pip 
    yum install -y mod_wsgi

    # Start Apache and enable it to run on boot
    systemctl start httpd
    systemctl enable httpd

    # Install Flask and other Python dependencies
    pip3 install flask

    # Create Flask application
    cat <<EOT > /var/www/html/app.py
    from flask import Flask
    app = Flask(__name__)

    @app.route('/')
    def hello_world():
        return "Hello, Basic Python Flask App"

    if __name__ == '__main__':
        app.run(host='0.0.0.0')
    EOT

    # Create Apache config for mod_wsgi to serve the app
    cat <<EOT > /etc/httpd/conf.d/flask_app.conf
    <VirtualHost *:80>
        ServerName localhost

        WSGIDaemonProcess flaskapp user=apache group=apache threads=5
        WSGIScriptAlias / /var/www/html/app.py

        <Directory /var/www/html>
            WSGIProcessGroup flaskapp
            WSGIApplicationGroup "GLOBAL"
            Require all granted
        </Directory>
    </VirtualHost>
    EOT

    # Restart Apache to apply changes
    systemctl restart httpd
  EOF

  tags = {
    Name = "Basic-Python-Flask-App"
  }
}

# Output public IP
output "lamp_server_ip" {
  value = aws_instance.basic_flask_app.public_ip
}


