/*creating main vpc - parent network*/
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "terraform-ha-vpc"
  }
}

/*adding first public subnet*/
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform-public-subnet-a"
  }
}

/*adding second public subnet*/
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform-public-subnet-b"
  }
}

/*creating internet gateway*/
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-main-igw"
  }
}

/*creating route table*/
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0" /*default route*/
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "terraform-public-route-table"
  }
}

/*Associating both subnets*/
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}


/*adding ALB sg*/
resource "aws_security_group" "alb" {
  name        = "terraform-alb-sg"
  description = "Security group for Terraform ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-alb-sg"
  }
}

/*Adding the ALB*/
resource "aws_lb" "web" {
  name               = "terraform-web-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  tags = {
    Name = "terraform-web-alb"
  }
}

/*Creating target group - 
The target group is essentially a pool of backend servers.
A target can be an EC2 instance, IP address, etc.
An AWS Load Balancer Target Group acts as a logical routing destination that directs incoming traffic from your Elastic Load Balancer (ELB) to one or more registered backend resources. Instead of routing traffic directly to individual servers, the load balancer's listeners evaluate incoming requests based on routing rules and forward them to the designated target group.*/
resource "aws_lb_target_group" "web" {
  name     = "terraform-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
  }

  tags = {
    Name = "terraform-web-target-group"
  }
}

/*Creating EC2 security groups*/
resource "aws_security_group" "ec2" {
  name        = "terraform-ec2-sg"
  description = "Security group for Terraform web servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "terraform-ec2-sg"
  }
}

/*Creating 2 EC2 instances*/
/*EC2-A*/
resource "aws_instance" "web_a" {
  ami           = "ami-06a83a7a581c729a9"
  instance_type = "t3.micro"

  subnet_id = aws_subnet.public_a.id

  vpc_security_group_ids = [
    aws_security_group.ec2.id
  ]

  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash

    dnf update -y
    dnf install -y nginx

    systemctl enable nginx
    systemctl start nginx

    echo "<h1>Hello from Terraform - Server A</h1>" > /usr/share/nginx/html/index.html
  EOF

  tags = {
    Name = "terraform-web-server-a"
  }
}

/*EC2-B*/
resource "aws_instance" "web_b" {
  ami           = "ami-06a83a7a581c729a9"
  instance_type = "t3.micro"

  subnet_id = aws_subnet.public_b.id

  vpc_security_group_ids = [
    aws_security_group.ec2.id
  ]

  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash

    dnf update -y
    dnf install -y nginx

    systemctl enable nginx
    systemctl start nginx

    echo "<h1>Hello from Terraform - Server B</h1>" > /usr/share/nginx/html/index.html
  EOF

  tags = {
    Name = "terraform-web-server-b"
  }
}

/*Register EC2 instances with the Target Group*/
resource "aws_lb_target_group_attachment" "web_a" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web_a.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web_b" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web_b.id
  port             = 80
}

/*Creaing the ALB Listener*/
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}