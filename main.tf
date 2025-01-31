terraform {
 required_providers {
   aws = {
     source = "hashicorp/aws"
     version = "5.83.1"
   }
 }
 required_version = ">= 1.1.5"
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}
#1 vpc
resource "aws_vpc" "roger_vpc" {
  cidr_block = var.vpc_cidr_block
  enable_dns_hostnames = true
  tags = {
    Name = "roger_vpc"
  }
}
#2 igw
resource "aws_internet_gateway" "roger_igw" {
  vpc_id = aws_vpc.roger_vpc.id
  tags = {
    Name = "roger_igw"
  }
}
#3 public subnet
resource "aws_subnet" "roger_public_subnet" {
  count = var.subnet_count.public
  vpc_id = aws_vpc.roger_vpc.id 
  cidr_block = var.public_subnet_cidr[count.index] 
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "roger_public_subnet_${count.index}"
  }
}
#private subnet
resource "aws_subnet" "roger_private_subnet" {
  count = var.subnet_count.private
  vpc_id = aws_vpc.roger_vpc.id 
  cidr_block = var.private_subnet_cidr[count.index] 
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "roger_private_subnet_${count.index}"
  }
}
#4 public rtb
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

#private rtb
resource "aws_route_table" "roger_private_rt" {
  vpc_id = aws_vpc.roger_vpc.id
}

resource "aws_route_table_association" "private" {
  count = var.subnet_count.private
  route_table_id = aws_route_table.roger_private_rt.id
  subnet_id = aws_subnet.roger_private_subnet[count.index].id
}
#5 EC2 security grp
resource "aws_security_group" "roger_web_sg" {
  name = "roger_web_sg"
  description = "security group for web servers"
  vpc_id = aws_vpc.roger_vpc.id

  ingress {
    description = "allow all traffic thro HTTP"
    from_port = "80"
    to_port = "80"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "allow SSH from my computer"
    from_port = "22"
    to_port = "22"
    protocol = "tcp"
    cidr_blocks = ["${var.my_ip}/32"] #using var "my_ip"
  }
  egress {
    description = "allow all outbound traffic"
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "roger_web_sg"
  }
}
#RDS security grp
resource "aws_security_group" "roger_db_sg" {
  name = "roger_db_sg"
  description = "security group for DB"
  vpc_id = aws_vpc.roger_vpc.id
  ingress {
    description = "allow MySQL traffic from only web_sg"
    from_port = "3306"
    to_port = "3306"
    protocol = "tcp"
    security_groups = [aws_security_group.roger_web_sg.id]
  }
  tags = {
    Name = "roger_db_sg"
  }
}
#6 create DB subnet grp
resource "aws_db_subnet_group" "roger_db_subnet_group" {
 name = "roger_db_subnet_group" 
 description = "db subnet group for roger"
 subnet_ids = [for subnet in aws_subnet.roger_private_subnet : subnet.id]
}
#7 create mySQL RDS
resource "aws_db_instance" "roger_database" {
  allocated_storage = var.settings.database.allocated_storage
  engine = var.settings.database.engine
  engine_version = var.settings.database.engine_version
  instance_class = var.settings.database.instance_class
  db_name = var.settings.database.db_name
  username = var.db_username
  password = var.db_password
  db_subnet_group_name = aws_db_subnet_group.roger_db_subnet_group.id
  vpc_security_group_ids = [aws_security_group.roger_db_sg.id]
  skip_final_snapshot = var.settings.database.skip_final_snapshot
}
#8 create key-pair, not sure if necessary if already created!
resource "aws_key_pair" "roger-debian-kp" {
  key_name = "roger-debian-kp"
  public_key = file("roger-debian-kp.pub")
  #public_key = file("terraform-rds/roger-debian-kp.pub") #public key of ssh
}
#create ubuntu ami
data "aws_ami" "ubuntu" {
  most_recent = "true"
  filter {
    name = "name"
    values = ["ubuntu-eks/k8s_1.24/images/hvm-ssd/ubuntu-focal-20.04-arm64-server-20231213.1"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}
#create EC2 roger_web
resource "aws_instance" "roger_web" {
  count = var.settings.web_app.count
  ami = data.aws_ami.ubuntu.id
  instance_type = var.settings.web_app.instance_type
  subnet_id = aws_subnet.roger_public_subnet[count.index].id
  key_name = aws_key_pair.roger-debian-kp.key_name
  vpc_security_group_ids = [aws_security_group.roger_web_sg.id]
  tags ={
    Name = "roger_web_${count.index}"
  }
}
#create elastic IP for EC2
resource "aws_eip" "roger_web_eip" {
  count = var.settings.web_app.count
  instance = aws_instance.roger_web[count.index].id
  #vpc = true
  tags = {
    Name = "roger_web_eip_${count.index}"
  }
}