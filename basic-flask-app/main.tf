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
  ami               = "ami-05c172c7f0d3aed00" # Ubuntu AMI
  instance_type     = "t2.micro"
  key_name          = "main-key"
  availability_zone = "eu-west-2a"
  security_groups   = [aws_security_group.basic_flask_app_sg.name]

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    lsb_release -a

    # Python stuff
    apt-get install python3-setuptools -y
    apt-get install python3 -y
    apt install python3-pip -y
    
    # Update repo
    add-apt-repository universe
    apt-get update

    # Install mod-wsgi
    apt-get install libapache2-mod-wsgi-py3

    # Install apache2
    apt-get update
    apt-get install apache2 -y

    # Start Apache and enable it to run on boot
    systemctl start apache2
    systemctl enable apache2

    # Install Flask and other Python dependencies
    apt install python3-flask -y

    # Create Flask application
    cat <<EOT > /var/www/html/app.py
    from flask import Flask
    app = Flask(__name__)

    @app.route('/')
    def hello_world():
        return "Hello, Basic Python Flask App"

    # Explicitly expose the application object
    application = app

    if __name__ == '__main__':
        app.run(host='0.0.0.0')
    EOT

    # Create Apache config for mod_wsgi to serve the app
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

    # Check Apache config syntax
    apachectl configtest

    # Restart Apache to apply changes
    sudo systemctl restart apache2
  EOF

  tags = {
    Name = "Basic-Python-Flask-App"
  }
}



# Output public IP
output "lamp_server_ip" {
  value = aws_instance.basic_flask_app.public_ip
}


