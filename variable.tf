# Define variables
variable "region" {
  description = "AWS region"
  default     = "us-east-1"  # Change to your desired region
}
variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  default     = "192.168.0.0/24"
}
variable "public_subnet_cidr_block_az1" {
  description = "CIDR block for the public subnet in the first availability zone"
  default     = "192.168.0.0/28"
}
variable "public_subnet_cidr_block_az2" {
  description = "CIDR block for the public subnet in the second availability zone"
  default     = "192.168.0.16/28"
}
variable "private_subnet_cidr_block_az2" {
  description = "CIDR block for the private subnet in the second availability zone"
  default     = "192.168.0.32/28"
}
variable "availability_zone_1" {
  description = "Availability Zone for the public subnet"
  default     = "us-east-1a"
}
variable "availability_zone_2" {
  description = "Availability Zone for the private and public subnet"
  default     = "us-east-1b"
}
variable "docker_image" {
  description = "Docker image to run on the private EC2 instance"
  default     = "tejaswinimalloju/dazn_test:v1"
}
# Declare variable for creating listener
variable "create_listener" {
  type    = bool
  default = true
}
variable "local_ip" {
  description = "Local system's public IP address"
  # Replace with your local system's IP address
  default     = "49.43.228.189"
}
