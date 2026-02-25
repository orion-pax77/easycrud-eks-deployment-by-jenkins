

provider "aws" {
  region = "us-east-1"
}

###################################
# Get Default VPC
###################################
data "aws_vpc" "default" {
  default = true
}

###################################
# Get Subnets
###################################
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

###################################
# Security Group for RDS
###################################
resource "aws_security_group" "rds_sg" {
  name        = "rds-mariadb-sg"
  description = "Allow MariaDB access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]   # ⚠ For testing only
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###################################
# DB Subnet Group
###################################
resource "aws_db_subnet_group" "rds_subnet" {
  name       = "rds-mariadb-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
}

###################################
# RDS MariaDB Instance (Free Tier)
###################################
resource "aws_db_instance" "mariadb" {
  identifier              = "easycrud-mariadb"
  allocated_storage       = 20
  max_allocated_storage   = 20

  engine                  = "mariadb"
  engine_version          = "11.8.5"   # Free-tier supported stable version

  instance_class          = "db.t4g.micro"
  storage_type            = "gp2"

  db_name                 = "easycruddb"
  username                = "admin"
  password                = "redhat123"

  db_subnet_group_name    = aws_db_subnet_group.rds_subnet.name
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]

  publicly_accessible     = true
  multi_az                = false
  skip_final_snapshot     = true
  deletion_protection     = false

  backup_retention_period = 0
  performance_insights_enabled = false
  auto_minor_version_upgrade    = true

  tags = {
    Name = "EasyCRUD-MariaDB"
  }
}

###################################
# Outputs
###################################
output "rds_endpoint" {
  value = aws_db_instance.mariadb.address
}

output "rds_port" {
  value = aws_db_instance.mariadb.port
}
