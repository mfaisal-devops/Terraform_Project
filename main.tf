terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "lti_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "LTI_VPC"
  }
}

resource "aws_subnet" "lti_public_subnet" {
  vpc_id     = aws_vpc.lti_vpc.id
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "LTI_Public_Subnet"
  }
}

resource "aws_subnet" "lti_private_subnet" {
  vpc_id     = aws_vpc.lti_vpc.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "LTI_Private_Subnet"
  }
}

resource "aws_internet_gateway" "lti_igw" {
  vpc_id = aws_vpc.lti_vpc.id

  tags = {
    Name = "LTI_Internet_Gateway"
  }
}

resource "aws_route_table" "lti_public_route_table" {
  vpc_id = aws_vpc.lti_vpc.id

  route {
    cidr_block = "0.0.0.0"
    gateway_id = aws_internet_gateway.lti_igw.id
  }

  tags = {
    Name = "LTI_Public_Route_Table"
  }
}

resource "aws_route_table_association" "lti_public_route_table_association" {
  subnet_id      = aws_subnet.lti_public_subnet.id
  route_table_id = aws_route_table.lti_public_route_table.id
}

resource "aws_eip" "lti_eip" {
  domain   = "vpc"
}

resource "aws_nat_gateway" "lti_nat_gateway" {
  allocation_id = aws_eip.lti_eip.id
  subnet_id     = aws_subnet.lti_public_subnet.id

  tags = {
    Name = "gw NAT"
  }

  depends_on = [aws_internet_gateway.lti_igw]
}

resource "aws_route_table" "lti_private_route_table" {
  vpc_id = aws_vpc.lti_vpc.id

  route {
    cidr_block = "0.0.0.0"
    nat_gateway_id = aws_nat_gateway.lti_nat_gateway.id
  }

  tags = {
    Name = "LTI_Private_Route_Table"
  }
}

resource "aws_route_table_association" "lti_private_route_table_association" {
  subnet_id      = aws_subnet.lti_private_subnet.id
  route_table_id = aws_route_table.lti_private_route_table.id
}

resource "aws_security_group" "lti_security_group" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.lti_vpc.id

  tags = {
    Name = "LTI_Security_Group"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_tls_ipv4" {
  security_group_id = aws_security_group.lti_security_group.id
  cidr_ipv4         = aws_vpc.lti_vpc.cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.lti_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_security_group" "app_security_group" {
  name        = "app_server_sg"
  description = "Security group for application server"
  vpc_id      = aws_vpc.lti_vpc.id

  tags = {
    Name = "App_Security_Group"
  }
}

# Allow SSH access
resource "aws_vpc_security_group_ingress_rule" "app_allow_ssh" {
  security_group_id = aws_security_group.app_security_group.id
  cidr_ipv4         = aws_vpc.lti_vpc.cidr_block
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "app_allow_port_8080" {
  security_group_id = aws_security_group.app_security_group.id
  cidr_ipv4         = aws_vpc.lti_vpc.cidr_block
  from_port         = 8080
  ip_protocol       = "tcp"
  to_port           = 8080
}

resource "aws_vpc_security_group_egress_rule" "app_allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.app_security_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" 
}

resource "aws_instance" "lti_webserver_1" {
  ami           = "ami-04b0b8ee9ce90920a"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.lti_public_subnet.id
  vpc_security_group_ids = [aws_security_group.lti_security_group.id]
  key_name      = "Terraform_Project_12.key"

  tags = {
    Name = "LTI_WebServer_1"
  }
}

resource "aws_instance" "lti_appserver_1" {
  ami           = "ami-04b0b8ee9ce90920a"
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.lti_private_subnet.id
  vpc_security_group_ids = [aws_security_group.app_security_group.id]
  key_name      = "Terraform_Project_12.key"

  tags = {
    Name = "LTI_WebServer_1"
  }
}





