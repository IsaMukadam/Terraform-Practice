##------------------ Config --------------------##
provider "aws" {
    region  = "eu-west-2"
}

##------------------ VPC (Dev) --------------------##
resource "aws_vpc" "dev-vpc" {
    cidr_block = "10.0.0.0/16"

    tags = {
      Name = "Dev VPC"
    }
}
 
##------------------ Subnet 1 (Dev) --------------------##
resource "aws_subnet" "subnet-1" {
    vpc_id     = aws_vpc.dev-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-west-2a"

    tags = {
      Name = "Dev Subnet-1" 
    } 
}

##------------------ Subnet 2 (Dev) --------------------##
resource "aws_subnet" "subnet-2" {
    vpc_id     = aws_vpc.dev-vpc.id
    cidr_block = "10.0.2.0/24"
    availability_zone = "eu-west-2b"

    tags = {
      Name = "Dev Subnet-2" 
    } 
} 

##------------------ Subnet 3 (Dev) --------------------##
resource "aws_subnet" "subnet-3" {
    vpc_id     = aws_vpc.dev-vpc.id
    cidr_block = "10.0.3.0/24"
    availability_zone = "eu-west-2c"

    tags = {
      Name = "Dev Subnet-3" 
    } 
} 

##------------------ VPC (Prod) --------------------##
resource "aws_vpc" "prod-vpc" {
    cidr_block = "12.0.0.0/16"

    tags = {
      Name = "Prod VPC"
    }
}

##------------------ Subnet 1 (Prod) --------------------##
resource "aws_subnet" "subnet-1" {
    vpc_id     = aws_vpc.prod-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-west-2a"

    tags = {
      Name = "Prod Subnet-1" 
    } 
} 