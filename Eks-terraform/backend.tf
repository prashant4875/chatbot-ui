terraform{
    backend "s3" {
      bucket = "eks-bucket-4875"
      key = "terraform.tfstate"
      region = "us-east-1"
    }
}