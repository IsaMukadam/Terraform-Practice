provider "aws" {
    region  = "eu-west-2"
}

resource "aws_vpc" "test-vpc" {
    cidr_block = "10.0.0.0/16"

    tags = {
      Name = "Test VPC"
    }
}

resource "aws_subnet" "subnet-1" {
    vpc_id     = aws_vpc.test-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-west-2a"

    tags = {
      Name = "Subnet-1" 
    } 
}

resource "aws_subnet" "subnet-2" {
    vpc_id     = aws_vpc.test-vpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "eu-west-2b"

    tags = {
      Name = "Subnet-2" 
    } 
} 

resource "aws_subnet" "subnet-3" {
    vpc_id     = aws_vpc.test-vpc.id
    cidr_block = "10.0.3.0/24"
    availability_zone = "eu-west-2c"

    tags = {
      Name = "Subnet-3" 
    } 
} 