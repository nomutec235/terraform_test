variable "region" {
  default = "ap-northeast-1"
}

variable "images" {
  default = {
    ami = "ami-0b7546e839d7ace12"
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Name = "nomura-test-public"
    }
  }

}

#----------------------------------------
# VPCの作成
#----------------------------------------
resource "aws_vpc" "nomura_test_vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  tags = {
    Name = "nomura-test-vpc"
  }

}

#----------------------------------------
# public subnetの作成
#----------------------------------------
resource "aws_subnet" "nomura-test-public-a" {
  vpc_id                  = aws_vpc.nomura_test_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "nomura-test-public-a"
  }
}

#----------------------------------------
# igwの作成
#----------------------------------------
resource "aws_internet_gateway" "nomura_test_igw" {
  vpc_id = aws_vpc.nomura_test_vpc.id # myVPCのid属性を参照
  tags = {
    Name = "nomura_test_igw"
  }
}

#----------------------------------------
# ルートテーブルの作成
#----------------------------------------
resource "aws_route_table" "nomura-public-route" {
  vpc_id = aws_vpc.nomura_test_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nomura_test_igw.id
  }
  tags = {
    Name = "nomura-public-route"
  }

}

#----------------------------------------
# サブネットにルートテーブル紐付け
#----------------------------------------
resource "aws_route_table_association" "route-table-puclic-a" {
  subnet_id      = aws_subnet.nomura-test-public-a.id
  route_table_id = aws_route_table.nomura-public-route.id
}

#----------------------------------------
# セキュリティグループの作成
#----------------------------------------
resource "aws_security_group" "nomura-test-sg" {
  name        = "nomura-test-sg"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.nomura_test_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "nomura-test-sg"
  }
}

#----------------------------------------
# EC2インスタンスの作成
#----------------------------------------
resource "aws_instance" "nomura-instance-web-server-a" {
  ami           = var.images.ami
  instance_type = "t2.micro"
  key_name      = "aws-nomura-network-test-key"
  subnet_id     = aws_subnet.nomura-test-public-a.id
  vpc_security_group_ids = [
    "${aws_security_group.nomura-test-sg.id}"
  ]
  tags = {
    Name = "nomura-instance-web-server-a"
  }

  user_data = <<EOF
#! /bin/bash
sudo yum install -y httpd
sudo systemctl start httpd.service
sudo systemctl enable httpd.service
cd /var/www/html/
sudo touch index.html
sudo echo "hello world!!!!" > index.html
EOF
}


