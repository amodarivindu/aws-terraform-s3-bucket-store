# aws-terraform-s3-bucket-store
Here I stored images and state file into the s3 bucket and provisionning those s3 bucket using terraform
# AWS S3 Bucket Provisioning with Terraform

This repository contains a Terraform configuration to create multiple environment-specific Amazon S3 buckets in AWS and upload files from a local `images` folder to the buckets with server-side encryption.

## Overview

The configuration deploys S3 buckets across multiple environments (dev, prod, staging) using the AWS provider. Each bucket can be configured independently, with optional file uploads and encryption enabled. The Terraform code uses `for_each` to iterate over environment configurations and create buckets dynamically.

## Repository Structure

- `main.tf` - Defines AWS S3 bucket resources and S3 object upload configuration.
- `provider.tf` - Configures the Terraform AWS provider and required Terraform version.
- `variables.tf` - Declares input variables for AWS region and multi-environment bucket configuration.
- `outputs.tf` - Exposes the list of created bucket names.
- `terraform.tfvars` - Provides environment-specific bucket configuration and values.
- `terraform.tfstate`, `terraform.tfstate.backup` - Terraform state files generated during apply/destroy.
- `images/` - Local directory containing files to upload to S3 buckets.

## Files and Configuration

### `provider.tf`

This file contains provider configuration and required Terraform settings.

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}
```

- `required_providers` declares the AWS provider version from HashiCorp (AWS provider 5.0+).
- `required_version` ensures Terraform 1.0 or later is used.
- The AWS provider is configured with `region = var.aws_region`.

### `variables.tf`

Defines input variables:

```hcl
variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "bucket_names" {
  type = map(object({
    name          = string
    upload_images = bool
  }))
}
```

- `aws_region` (string): The AWS region where the S3 buckets will be created (e.g., `us-east-1`).
- `bucket_names` (map of object): A map where each key is the environment name (e.g., "dev", "prod", "staging") and each value is an object containing:
  - `name` (string): The S3 bucket name (must be globally unique across AWS).
  - `upload_images` (bool): Whether to upload files from the `images` folder to this bucket.

### `main.tf`

Contains two main resources:

#### 1. S3 Bucket Resource

```hcl
resource "aws_s3_bucket" "multiple_buckets" {
  for_each = var.bucket_names

  bucket = each.value.name

  tags = {
    Name        = each.value.name
    Environment = each.key
  }
}
```

- Creates S3 buckets using a `for_each` loop over `var.bucket_names`.
- Each bucket is named using `each.value.name`.
- Tags are applied to identify the bucket name and environment.

#### 2. S3 Object Upload Resource

```hcl
resource "aws_s3_object" "upload_files" {
  for_each = fileset("./images", "*")

  bucket = aws_s3_bucket.multiple_buckets["dev"].id
  key    = each.value
  source = "./images/${each.value}"
  etag   = filemd5("./images/${each.value}")
  server_side_encryption = "AES256"
}
```

- Uploads all files from the `./images` folder to the S3 bucket.
- `fileset("./images", "*")` discovers all files in the `images` directory.
- `bucket` specifies the target bucket (currently set to "dev" bucket).
- `key` is the object name in S3 (same as the file name).
- `source` specifies the local file path.
- `etag = filemd5(...)` detects file changes and triggers re-uploads when files are modified.
- `server_side_encryption = "AES256"` enables AES-256 server-side encryption for security.

### `outputs.tf`

```hcl
output "bucket_names" {
  value = [for b in aws_s3_bucket.multiple_buckets : b.bucket]
}
```

Outputs a list of all created bucket names after applying the configuration.

### `terraform.tfvars`

Provides the actual values for variables:

```hcl
aws_region = "us-east-1"

bucket_names = {
  dev = {
    name          = "amoda-dev-bucket-001"
    upload_images = true
  }

  prod = {
    name          = "amoda-prod-bucket-001"
    upload_images = false
  }

  staging = {
    name          = "amoda-staging-bucket-001"
    upload_images = true
  }
}
```

- AWS region is set to `us-east-1`.
- Three environments are configured: `dev`, `prod`, and `staging`.
- Each environment has a unique bucket name and a flag to control file uploads.
- Dev and staging buckets have `upload_images = true`, so files will be uploaded.
- Prod bucket has `upload_images = false`, so no files will be uploaded.

## Prerequisites

- **Terraform** installed (`>= 1.0`).
- **AWS account** with appropriate credentials.
- **AWS credentials** configured locally using one of the following methods:
  - Environment variables: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
  - AWS CLI configured profile
  - IAM role (for AWS instances or services)
- **`images/` folder** in the project root containing files to upload (optional if `upload_images` is set to `false` for all buckets).

## Usage

From the repository root directory, run the following commands:

### 1. Initialize Terraform

```bash
terraform init
```

This downloads the AWS provider and initializes the Terraform workspace.

### 2. Preview the plan

```bash
terraform plan
```

This shows what resources will be created without making any changes.

### 3. Apply the configuration

```bash
terraform apply
```

This creates the S3 buckets and uploads files as configured. You'll be prompted to confirm before proceeding.

To skip the confirmation prompt:

```bash
terraform apply --auto-approve
```

### 4. Destroy the created resources

```bash
terraform destroy
```

This removes all S3 buckets and uploaded objects. Use with caution, as this deletes all data.

## Configuration Details

### Multi-Environment Setup

The current configuration creates three S3 buckets:

1. **dev** - `amoda-dev-bucket-001` - Files uploaded with encryption
2. **prod** - `amoda-prod-bucket-001` - No file uploads
3. **staging** - `amoda-staging-bucket-001` - Files uploaded with encryption

### File Upload

- Files from the `./images` folder are uploaded to the "dev" bucket.
- Files are encrypted using AES-256 server-side encryption.
- The `etag` ensures files are re-uploaded if their content changes.
- To upload to a different bucket, change the bucket key in the `aws_s3_object` resource from `["dev"]` to `["prod"]` or `["staging"]`.

### S3 Bucket Policy

For the dev bucket (`amoda-dev-bucket-001`), you can apply a bucket policy to allow public read access to the uploaded images. This is useful for serving static content like images publicly.

#### Example Bucket Policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::amoda-dev-bucket-001/*"
    }
  ]
}
```

#### Policy Explanation

- **Version**: `"2012-10-17"` - This is the IAM policy language version. It's the standard version for most AWS policies.
- **Statement**: An array of policy statements. This policy has one statement.
  - **Sid**: `"PublicReadGetObject"` - A unique identifier for this statement (optional but recommended for clarity).
  - **Effect**: `"Allow"` - Grants permission for the specified action.
  - **Principal**: `"*"` - Applies to all users (public access). This makes the bucket publicly readable.
  - **Action**: `"s3:GetObject"` - Allows reading (downloading) objects from the bucket.
  - **Resource**: `"arn:aws:s3:::amoda-dev-bucket-001/*"` - Applies to all objects (`/*`) in the specified bucket (`amoda-dev-bucket-001`).

#### Applying the Policy in Terraform

To apply this policy using Terraform, add the following resource to your `main.tf`:

```hcl
resource "aws_s3_bucket_policy" "dev_bucket_policy" {
  bucket = aws_s3_bucket.multiple_buckets["dev"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.multiple_buckets["dev"].arn}/*"
      }
    ]
  })
}
```

#### Security Considerations

- **Public Access Warning**: This policy grants public read access to all objects in the bucket. Anyone with the URL can access the files. Use this only for public content like website assets.
- **Production Use**: For production environments, consider using Amazon CloudFront with Origin Access Identity (OAI) for secure, cached public access without making the bucket fully public.
- **Encryption**: Even with public access, objects remain encrypted at rest with AES-256.
- **Cost**: Public buckets may incur additional costs if accessed frequently.

## Important Notes

- **S3 Bucket Names**: All bucket names must be globally unique across AWS. Ensure your bucket names don't conflict with existing buckets.
- **Images Folder**: Create an `images` folder in the project root and add files to be uploaded to S3. If the folder doesn't exist, Terraform will fail.
- **Encryption**: All uploaded objects are encrypted with AES-256 by default.
- **File Changes**: The `etag` field detects when files are modified locally and automatically uploads updated versions to S3.

## Example: Override Configuration

To override values without modifying `terraform.tfvars`, use the `-var` flag:

```bash
terraform apply -var='aws_region=us-west-2'
```

To change bucket configuration:

```bash
terraform apply -var='bucket_names={
  dev = {
    name = "my-custom-dev-bucket"
    upload_images = true
  }
}'
```

## Output Example

After running `terraform apply`, the output will show:

```text
bucket_names = [
  "amoda-dev-bucket-001",
  "amoda-prod-bucket-001",
  "amoda-staging-bucket-001"
]
```

## State Management

- `terraform.tfstate` - The current state of your infrastructure.
- `terraform.tfstate.backup` - Backup of the previous state.
- These files should not be committed to version control in production environments. Use remote state (e.g., S3, Terraform Cloud) for team collaboration.

## Troubleshooting

1. **Bucket name already exists**: S3 bucket names are globally unique. Choose a different name in `terraform.tfvars`.
2. **Images folder not found**: Create an `images` directory in the project root and add files to it.
3. **AWS credentials not found**: Ensure your AWS credentials are configured via environment variables, AWS CLI, or IAM role.
4. **Permission denied**: Ensure your AWS IAM user has permissions to create S3 buckets and upload objects.

## Summary

This Terraform project provides a complete solution for:
- Creating environment-specific S3 buckets
- Uploading files with AES-256 encryption
- Managing multi-environment infrastructure as code
- Tracking and detecting file changes automatically

It is suitable for development, staging, and production deployments with environment-specific configurations.
