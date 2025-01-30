terraform {
 required_providers {
   aws = {
     source = "hashicorp/aws"
     version = "5.83.1"
   }
 }
 required_version = "-> 1.1.5"
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "roger_vpc" {
  cidr_block = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags = {
    Name = "roger_vpc"
  }
}

resource "aws_internet_gateway" "roger_igw" {
  vpc_id = aws_vpc.roger_vpc.id
  tags = {
    Name = "roger_igw"
  }
}

resource "aws_subnet" "roger_public_subnet" {
  count = var.subnet_count.public
  vpc_id = aws_vpc.roger_vpc.id 
  cidr_block = var.public_subnet_cidr[count.index] 
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "roger_public_subnet_${count.index}"
  }
}

resource "aws_subnet" "roger_private_subnet" {
  count = var.subnet_count.private
  vpc_id = aws_vpc.roger_vpc.id 
  cidr_block = var.private_subnet_cidr[count.index] 
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "roger_private_subnet_${count.index}"
  }
}

resource "aws_route_table" "roger_public_rt" {
  vpc_id = aws_vpc.roger_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.roger_igw.id
  }
}

resource "aws_route_table_association" "public" {
  count = var.subnet_count.public
  route_table_id = aws_route_table.roger_public_rt.id
  subnet_id = aws_subnet.roger_public_subnet[count.index].id
}


resource "aws_route_table" "roger_private_rt" {
  vpc_id = aws_vpc.roger_vpc.id
}

resource "aws_route_table_association" "private" {
  count = var.subnet_count.private
  route_table_id = aws_route_table.roger_private_rt.id
  subnet_id = aws_subnet.roger_private_subnet[count.index].id
}

#stopped at Step5 Creating Security Groups