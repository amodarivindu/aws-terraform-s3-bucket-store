resource "aws_s3_bucket" "multiple_buckets" {
  for_each = var.bucket_names

  bucket = each.value.name

  tags = {
    Name        = each.value.name  #each.value = value of the current element in the iteration(dev, prod, staging) and name is the attribute of the object defined in variables.tf  
    Environment = each.key
  }
}

#upload all files from images folder to s3 bucket
resource "aws_s3_object" "upload_files" {
  for_each = fileset("./images", "*")

  bucket = aws_s3_bucket.multiple_buckets["dev"].id
  key    = each.value
  source = "./images/${each.value}"
  etag   = filemd5("./images/${each.value}")
  server_side_encryption = "AES256"
   
}

# Disable Public Access Block
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.multiple_buckets["dev"].id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket Policy
resource "aws_s3_bucket_policy" "public_policy" {
  bucket = aws_s3_bucket.multiple_buckets["dev"].id

  depends_on = [
    aws_s3_bucket_public_access_block.public_access
  ]

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid = "PublicReadGetObject"

        Effect = "Allow"

        Principal = "*"

        Action = [
          "s3:GetObject"
        ]

        Resource = [
          "${aws_s3_bucket.multiple_buckets["dev"].arn}/*"
        ]
      }
    ]
  })
}
