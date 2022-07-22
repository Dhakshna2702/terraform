terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-1"
}

# Configure VPC
resource "aws_vpc" "VPC" {
  cidr_block       = "10.129.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "VPC-dhaks-euwe1"
  }
}

#configure the web subnet
resource "aws_subnet" "pubsnt" {
  vpc_id     = aws_vpc.VPC.id
  cidr_block = "10.129.0.0/24"

  tags = {
    Name = "snt-dhaksh-euwe1-web"
  }
}

#configure the app subnet
resource "aws_subnet" "pvtsnt" {
  vpc_id     = aws_vpc.VPC.id
  cidr_block = "10.129.1.0/24"

  tags = {
    Name = "snt-dhaksh-euwe1-app"
  }
}

#attahing internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.VPC.id

  tags = {
    Name = "igw-dhaksh-euwe1"
  }
}

#Create public routing table
resource "aws_route_table" "pubrtb" {
  vpc_id = aws_vpc.VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "rtb-dhaksh-euwe1-web"
  }
}

#Subnet association
resource "aws_route_table_association" "pubassoc" {
  subnet_id      = aws_subnet.pubsnt.id
  route_table_id = aws_route_table.pubrtb.id
}

#Allocation Elastic IP
resource "aws_eip" "elip" {
  vpc      = true
}

#Create NAT Gateway

resource "aws_nat_gateway" "NAT" {
  allocation_id = aws_eip.elip.id
  subnet_id     = aws_subnet.pubsnt.id

  tags = {
    Name = "ngw-dhaksh-euwe1"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  #depends_on = [aws_internet_gateway.example]
}

#Create private routing table
resource "aws_route_table" "pvtrtb" {
  vpc_id = aws_vpc.VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.NAT.id
  }

  tags = {
    Name = "rtb-dhaksh-euwe1-app"
  }
}

#Subnet association
resource "aws_route_table_association" "pvtassoc" {
  subnet_id      = aws_subnet.pvtsnt.id
  route_table_id = aws_route_table.pvtrtb.id
}

#find my ipaddress
data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

#create pub security group
resource "aws_security_group" "pubsg" {
  name        = "allow_from_myip"
  description = "Allow the inbound traffic"
  vpc_id      = aws_vpc.VPC.id

  ingress {
    description      = "RDP from VPC"
    from_port        = 3389
    to_port          = 3389
    protocol         = "RDP"
    cidr_blocks      = ["${chomp(data.http.myip.body)}/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "stg-dhaksh-euwe1-web"
  }
} 

#create pvt security group
resource "aws_security_group" "pvtsg" {
  name        = "allow_from_myip"
  description = "Allow the inbound traffic"
  vpc_id      = aws_vpc.VPC.id

  ingress {
    description      = "Allow All TCP"
    from_port        = 0
    to_port          = 65535
    protocol         = "All TCP"
    cidr_blocks      = ["sg-0987654321"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "stg-dhaksh-euwe1-app"
  }
}
