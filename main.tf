terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "saja-project1"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "saja-public-subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.10.0/24"
  map_public_ip_on_launch = false
  tags = {
    Name = "saja-private-subnet"
  }
}

  resource "aws_security_group" "saja_public_sg" {
  name        = "saja-public-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "saja-public-sg"
  }
}

resource "aws_security_group" "saja_private_sg_redis" {
  name        = "saja-private-sg"
  description = "Allow TLS inbound traffic and all outbound traffic only from the same sg"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "saja-private-sg"
  }
}

resource "aws_security_group" "saja_private_sg_postgresql" {
  name        = "saja-db-sg"
  description = "Allow TLS inbound traffic and all outbound traffic into db from private subnet"
  vpc_id      = aws_vpc.main.id
  ingress{
from_port       = 22               # or 5432 for DB access
    to_port         = 22
    protocol        = "tcp"
    security_groups = [
      aws_security_group.saja_private_sg_redis.id,
      aws_security_group.saja_public_sg.id,
    ]
}
ingress{
from_port       = 5432               # or 5432 for DB access
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.saja_private_sg_redis.id]
}
ingress{
from_port       = 5432               # or 5432 for DB access
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.saja_public_sg.id]
}

  tags = {
    Name = "saja-db-sg"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_eip" "nat-saja" {
  domain = "vpc"
  tags = { Name = "nat-eip-saja" }
}

resource "aws_nat_gateway" "nat_saja" {
  allocation_id = aws_eip.nat-saja.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "gw NAT saja"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_instance" "front_end_ec2" {
  ami           = "ami-01760eea5c574eb86"
  vpc_security_group_ids = [aws_security_group.saja_public_sg.id]
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name = "saja"
  tags = {
    Name = "front-end-ec2"
  }
}

resource "aws_instance" "back_end_ec2" {
  ami           = "ami-01760eea5c574eb86"
  vpc_security_group_ids = [aws_security_group.saja_private_sg_redis.id]
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.private_subnet.id
  key_name = "saja"
  tags = {
    Name = "back-end-ec2"
  }
}

resource "aws_instance" "db_ec2" {
  ami           = "ami-01760eea5c574eb86"
  vpc_security_group_ids = [aws_security_group.saja_private_sg_postgresql.id]
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.private_subnet.id
  key_name = "saja"
  tags = {
    Name = "db-ec2"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_in_443" {
  security_group_id = aws_security_group.saja_public_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "allow_in_8080" {
  security_group_id = aws_security_group.saja_public_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_in_81" {
  security_group_id = aws_security_group.saja_public_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 81
  ip_protocol       = "tcp"
  to_port           = 81
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route" "public_igw" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route" "nat" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id             = aws_nat_gateway.nat_saja.id
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_in_22" {
  security_group_id = aws_security_group.saja_public_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_public_out" {
  security_group_id = aws_security_group.saja_public_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_ingress_rule" "allow_private_in_22" {
  security_group_id = aws_security_group.saja_private_sg_redis.id
  cidr_ipv4         = aws_vpc.main.cidr_block
  from_port         = 22 
  ip_protocol       = "tcp"
  to_port           = 22 
}

resource "aws_vpc_security_group_ingress_rule" "allow_private_for_redis" {
  security_group_id = aws_security_group.saja_private_sg_redis.id
  referenced_security_group_id   = aws_security_group.saja_public_sg.id
  from_port         = 6379 
  ip_protocol       = "tcp"
  to_port           = 6379 
}

resource "aws_vpc_security_group_egress_rule" "allow_private_out" {
  security_group_id = aws_security_group.saja_private_sg_redis.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "allow_private_out_db" {
  security_group_id = aws_security_group.saja_private_sg_postgresql.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

