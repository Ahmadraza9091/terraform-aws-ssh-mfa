provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "google-auth-instance" {
  ami           = "ami-0b6d9d3d33ba97d99"
  instance_type = "t3.micro"
  key_name      = "linux_practice"
  subnet_id     = "subnet-09320a9f8c774f0a6"

  user_data = file("${path.module}/user_data.sh")

  associate_public_ip_address = true
  tags = {
    Name = "google-auth-instance"
  }
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "terraform-state-bucket-ahmad-2026"
}