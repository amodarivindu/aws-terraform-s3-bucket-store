terraform {
  backend "s3" {
    bucket = "amoda-demo-terraform-bucket-backend-tfstate01"
    key    = "ec2-setup/tfstate"
    region = "us-east-1"
  }
}