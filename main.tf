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