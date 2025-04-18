variable "aws_region" {
  default = "us-east-1"
}

variable "vpc_cidr_block" {
  description = "CIDR block for VPC"
  type = string
  default = "10.0.0.0/16"
}

variable "subnet_count" {
  description = "Number of subnets"
  type = map(number)
  default = {
    public = 1,
    private = 2
  }
}

variable "settings" {
  description = "Configuration settings"
  type = map(any)
  default = {
    "database" = {
      allocated_storage = 10
      db_name           = "roger_db"
      engine            = "mysql"
      engine_version    = "8.0"
      instance_class    = "db.t3.micro"
      parameter_group_name = "default.mysql8.0"
      skip_final_snapshot = true
    },
    "web_app" = {
      count         = 1
      instance_type = "t2.micro"
    }
  }
}


variable "public_subnet_cidr" {
  description = "Available CIDR-public subnets"
  type = list(string)
  default = [ 
    "10.0.1.0/24",
    "10.0.2.0/24",
    "10.0.3.0/24",
    "10.0.4.0/24"
   ]
}

variable "private_subnet_cidr" {
  description = "Available CIDR-private subnets"
  type = list(string)
  default = [ 
    "10.0.101.0/24",
    "10.0.102.0/24",
    "10.0.103.0/24",
    "10.0.104.0/24"
   ]
}

#terraform.tfvars
variable "my_ip" {
  description = "Your IP address"
  type = string
  sensitive = true
}

variable "db_username" {
  description = "Database master user"
  type = string
  sensitive = true
}

variable "db_password" {
  description = "Database master user password"
  type = string
  sensitive = true
}