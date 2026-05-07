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
