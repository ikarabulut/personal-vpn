terraform {
  backend "s3" {
    bucket         = "personal-vpn-backend"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"

    dynamodb_table = "personal-vpn-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name      = aws_key_pair.myKeyPair.key_name
  vpc_security_group_ids = [aws_security_group.SshSG.id]

  subnet_id = "subnet-00084671f7a4e7538"

  tags = {
    Name = "personal-vpn-instance"
  }
}

resource "tls_private_key" "tls_connector" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "myKeyPair" {
  key_name   = "myLabKeyPair"
  public_key = tls_private_key.tls_connector.public_key_openssh
}

resource "local_file" "myLabKeyPairFile" {
    content     = tls_private_key.tls_connector.private_key_pem
    filename    = "myKeyPair.pem"
    file_permission = "0400"
}

resource "aws_security_group" "SshSG" {
    name        = "sshSG"
    description = "Allow ssh"
    vpc_id = "vpc-0018812477372bf42"
    
    ingress {
        from_port   = "22"
        to_port     = "22"
        protocol    = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = "22"
        to_port     = "22"
        protocol    = "UDP"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port   = "51820"
        to_port     = "51820"
        protocol    = "UDP"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

