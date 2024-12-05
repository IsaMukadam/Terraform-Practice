## Provider Information
provider "aws" {
    region  = "eu-west-2"
}


## AWS Single Test Instance 
resource "aws_instance" "my-test-server" {
    ami           = "ami-0c76bd4bd302b30ec"
    instance_type = "t2.micro"
    tags = {
    Name = "Linux Server"
    Type = "t2.micro"
     }
}

