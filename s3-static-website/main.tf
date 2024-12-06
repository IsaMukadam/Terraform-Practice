provider "aws" {
  region = "eu-west-2"
}

############################################ S3 BUCKET SETUP ################################################

# Create S3 Bucket To Store Website Files
resource "aws_s3_bucket" "website_bucket" {
  bucket = "web_server_bucket_22138"

  website {
    index_document = "index.html"
    # Error document
    # error_document = "error.html"
  }
}

# Upload website files to S3
resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.website_bucket.name
  key    = "index.html"
  source = "/workspace/Terraform-Practice/web-app/index.html"  # Path to your local index.html
}

resource "aws_s3_object" "style" {
  bucket = aws_s3_bucket.website_bucket.name
  key = "style.css"
  source = "/workspace/Terraform-Practice/web-app/style.css"
}

# Bucket policy to allow public read access
resource "aws_s3_bucket_policy" "website_policy" {
  bucket = aws_s3_bucket.website_bucket.name
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
  value = aws_s3_bucket.website_bucket.website_endpoint
}