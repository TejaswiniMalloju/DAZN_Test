# Create Docker image resource
resource "null_resource" "docker_image" {
  provisioner "local-exec" {
    command     = "cmd /C build_and_push.bat"
    working_dir = "${path.module}"
  }
}

# AWS Provider
provider "aws" {
  region = var.region
}

# Create VPC with internet gateway
resource "aws_vpc" "my_vpc" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = "my-vpc"
  }
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my-igw"
  }
}

# Create public subnet in the first availability zone
resource "aws_subnet" "public_subnet_az1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.public_subnet_cidr_block_az1
  availability_zone = var.availability_zone_1
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-az1"
  }
}

# Create public subnet in the second availability zone
resource "aws_subnet" "public_subnet_az2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.public_subnet_cidr_block_az2
  availability_zone = var.availability_zone_2
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-az2"
  }
}

# Create private subnet in the second availability zone
resource "aws_subnet" "private_subnet_az2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.private_subnet_cidr_block_az2
  availability_zone = var.availability_zone_2

  tags = {
    Name = "private-subnet-az2"
  }
}

# Create security group allowing SSH (port 22) and HTTP (port 80) traffic
resource "aws_security_group" "my_security_group" {
  vpc_id = aws_vpc.my_vpc.id

  # Allow SSH inbound traffic only from the local system's IP address
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.local_ip}/32"]
  }

  # Allow HTTP inbound traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch EC2 instance in private subnet in the second availability zone
resource "aws_instance" "private_ec2_az2" {
  ami                    = "ami-08a0d1e16fc3f61ea"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.private_subnet_az2.id
  key_name               = "dazn_test"
  
  # Specify the security group directly within the resource block
  security_groups        = [aws_security_group.my_security_group.id]

  # Install Docker and run container on port 80
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              service docker start
              docker run -d -p 80:80 ${var.docker_image}
              EOF

  # Trigger recreation of resource when user data changes
  lifecycle {
    create_before_destroy = true
  }
}

# Create load balancer in all subnets
resource "aws_lb" "my_lb" {
  name               = "my-lb"
  internal           = false
  load_balancer_type = "application"
  
  # Specify all subnets
  subnets            = [
    aws_subnet.public_subnet_az1.id,
    aws_subnet.public_subnet_az2.id
  ]

  # Allow SSH traffic only from the local system's IP address
  security_groups    = [aws_security_group.my_security_group.id]

  tags = {
    Name = "my-lb"
  }
}

# Create target group for private EC2 instances
resource "aws_lb_target_group" "private_target_group" {
  name     = "private-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id

  health_check {
    path                = "/"
    port                = 80
    protocol            = "HTTP"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Register private EC2 instances with target group
resource "aws_lb_target_group_attachment" "private_target_attachment_az2" {
  target_group_arn = aws_lb_target_group.private_target_group.arn
  target_id        = aws_instance.private_ec2_az2.id
}

# Add listener to load balancer
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.my_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.private_target_group.arn
  }
}

# Create route table for internet gateway
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "public_rt"
  }
}

# Associate public subnet AZ1 with the public route table
resource "aws_route_table_association" "public_subnet_az1_association" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.public_rt.id
}

# Associate public subnet AZ2 with the public route table
resource "aws_route_table_association" "public_subnet_az2_association" {
  subnet_id      = aws_subnet.public_subnet_az2.id
  route_table_id = aws_route_table.public_rt.id
}

# Create route table for private subnet
resource "aws_route_table" "private_rt_az2" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "private_rt_az2"
  }
}

# Create route for the private subnet
resource "aws_route" "private_subnet_route_az2" {
  route_table_id         = aws_route_table.private_rt_az2.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.my_nat_gateway.id
}

# Associate private subnet AZ2 with the private route table
resource "aws_route_table_association" "private_subnet_az2_association" {
  subnet_id      = aws_subnet.private_subnet_az2.id
  route_table_id = aws_route_table.private_rt_az2.id
}

# Create NAT gateway
resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.my_eip.id
  subnet_id     = aws_subnet.public_subnet_az1.id

  tags = {
    Name = "my-nat-gateway"
  }
}

# Create EIP for NAT gateway
resource "aws_eip" "my_eip" {
  vpc      = true

  tags = {
    Name = "my-eip"
  }
}
