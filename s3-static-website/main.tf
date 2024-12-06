provider "aws" {
    region = "eu-west-2"
}

############################################ S3 BUCKET SETUP ################################################

# Create S3 Bucket To Store Website Files
resource "aws_s3_bucket" "website_bucket" {
    bucket = "web-server-bucket-22138"
}

# Disabling the block public access on the bucket
resource "aws_s3_bucket_public_access_block" "website_block" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls = false
  ignore_public_acls = false
  block_public_policy = false
  restrict_public_buckets = false
}

# Set up Static Website Hosting Configuration
resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }
  # Optionally, specify an error document
  # error_document = "error.html"
}

# Upload website files to S3
resource "aws_s3_object" "index" {
    bucket = aws_s3_bucket.website_bucket.id
    key    = "index.html"
    source = "/workspace/Terraform-Practice/s3-static-website/index.html"  # Path to your local index.html
    content_type = "text/html; charset=utf-8"
}

resource "aws_s3_object" "style" {
    bucket = aws_s3_bucket.website_bucket.id
    key    = "style.css"
    source = "/workspace/Terraform-Practice/s3-static-website/style.css"
    content_type = "text/css; charset=utf-8"
}

# Bucket policy to allow public read access
resource "aws_s3_bucket_policy" "website_policy" {
    depends_on = [aws_s3_bucket_public_access_block.website_block]
    bucket = aws_s3_bucket.website_bucket.id
    policy = data.aws_iam_policy_document.website_policy.json
}

# IAM Policy Doc For S3 Bucket Public Access
data "aws_iam_policy_document" "website_policy" {
  statement {
    actions = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.website_bucket.bucket}/*"]
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = ["*"]
    }
  }
}

# Outputs
output "website_url" {
  value = "http://${aws_s3_bucket.website_bucket.bucket}.s3-website.eu-west-2.amazonaws.com"
}