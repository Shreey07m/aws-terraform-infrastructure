resource "aws_vpc" "tf-vpc" {
  cidr_block = var.cidr
}

resource "aws_subnet" "Subnet-1" {
  vpc_id                  = aws_vpc.tf-vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "Subnet-2" {
  vpc_id                  = aws_vpc.tf-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "tf-igw" {
  vpc_id = aws_vpc.tf-vpc.id
}

resource "aws_route_table" "tf-rt" {
  vpc_id = aws_vpc.tf-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tf-igw.id
  }
}

resource "aws_route_table_association" "rt-1" {
  subnet_id      = aws_subnet.Subnet-1.id
  route_table_id = aws_route_table.tf-rt.id
}

resource "aws_route_table_association" "rt-2" {
  subnet_id      = aws_subnet.Subnet-2.id
  route_table_id = aws_route_table.tf-rt.id
}

resource "aws_security_group" "ec2_sg" {
  name_prefix = "ec2-sg"
  vpc_id      = aws_vpc.tf-vpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {
    Name = "ec2-sg"
  }
}

resource "aws_s3_bucket" "tf-bucket" {
  bucket = "shreeya-tf-s3-bucket"
}

resource "aws_instance" "tf-ec2-1" {
  ami             = "ami-0b6d9d3d33ba97d99"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.Subnet-1.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  user_data       = (file("userdata1.sh"))
}

resource "aws_instance" "tf-ec2-2" {
  ami             = "ami-0f8a61b66d1accaee"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.Subnet-2.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  user_data       = (file("userdata2.sh"))

}

resource "aws_lb" "tf-alb" {
  name = "tf-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ec2_sg.id]
  subnets            = [aws_subnet.Subnet-1.id, aws_subnet.Subnet-2.id]

}

resource "aws_lb_target_group" "tf-tg" {
  name     = "tf-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.tf-vpc.id

  health_check {
    path                = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_target_group_attachment" "tg-attachment-1" {
  target_group_arn = aws_lb_target_group.tf-tg.arn
  target_id        = aws_instance.tf-ec2-1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "tg-attachment-2" {
  target_group_arn = aws_lb_target_group.tf-tg.arn
  target_id        = aws_instance.tf-ec2-2.id
  port             = 80
}

resource "aws_lb_listener" "tf-listener" {
  load_balancer_arn = aws_lb.tf-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tf-tg.arn
  }
}
