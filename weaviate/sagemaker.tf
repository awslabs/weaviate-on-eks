resource "aws_sagemaker_notebook_instance" "this" {
  name     = local.name
  role_arn = aws_iam_role.this.arn

  instance_type       = "ml.t2.medium"
  platform_identifier = "notebook-al2-v2"
  volume_size         = 128

  subnet_id       = element(module.vpc.private_subnets, 0)
  security_groups = [module.sagemaker_sg.security_group_id]

  instance_metadata_service_configuration {
    minimum_instance_metadata_service_version = 2
  }

  lifecycle_config_name = aws_sagemaker_notebook_instance_lifecycle_configuration.this.name

  tags = module.tags.tags
}

resource "aws_sagemaker_notebook_instance_lifecycle_configuration" "this" {
  name = local.name

   on_create = base64encode(
     <<-EOT
       #!/bin/bash

       set -e
     
       echo "Pull notebooks from S3"
       cd /
       cd home/ec2-user/SageMaker/
       aws s3 cp s3://${local.name}-${local.account_id}/notebooks/  . --recursive
       cd samsung
       mkdir manuals
       cd manuals
       wget https://downloadcenter.samsung.com/content/UM/202004/20200430224317044/COM_SM-A705U_A70_EN_UM_Q_10.0_040720_FINAL_AC.pdf
       wget https://downloadcenter.samsung.com/content/UM/202302/20230228054404713/SAM_S911_S916_S918_EN_UM_OS13_020223_FINAL_AC.pdf
       wget https://downloadcenter.samsung.com/content/UM/202303/20230320235618822/SAM_S901_S906_S908_EN_UM_OS13_012323_FINAL_AC.pdf
       wget https://downloadcenter.samsung.com/content/UM/202304/20230411102236798/SAM_A536_EN_UM_OS13_040523_FINAL.pdf
       wget https://downloadcenter.samsung.com/content/UM/202302/20230218070620497/SAM_F936_F721_EN_UM_OS13_013123_FINAL_AC.pdf
       
       cd /
       cd home/ec2-user/SageMaker/samsung/
       rm -rf ./dependencies
       mkdir ./dependencies
       cd ./dependencies
       echo "Downloading dependencies"
       curl -sS https://d2eo22ngex1n9g.cloudfront.net/Documentation/SDK/bedrock-python-sdk.zip > sdk.zip
       echo "Unpacking dependencies"
       # (SageMaker Studio system terminals don't have `unzip` utility installed)
       if command -v unzip &> /dev/null
       then
           unzip sdk.zip && rm sdk.zip && echo "Done"
       else
           echo "'unzip' command not found: Trying to unzip via Python"
           python -m zipfile -e sdk.zip . && rm sdk.zip && echo "Done"
       fi  
       
       cd /
       cd home/ec2-user/SageMaker/
       rm -rf lost+found/
       
       echo "Update permissions"
       cd /
       cd home/ec2-user/SageMaker/
       sudo chown -R ec2-user:ec2-user .
       
     EOT
   )
  on_start = base64encode(
     <<-EOT
       #!/bin/bash

       set -e

       echo "On start"
       
     EOT
  )
}

################################################################################
# IAM Role
################################################################################

resource "aws_iam_role" "this" {
  name = local.name

  assume_role_policy  = data.aws_iam_policy_document.this.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonSageMakerFullAccess","arn:aws:iam::aws:policy/AmazonS3FullAccess"]
  
  inline_policy {
    name = local.name

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "Bedrock",
          Effect   = "Allow",
          Action   = ["bedrock:*"],
          Resource = ["*"]
        }
      ]
    })
  }
  
  tags = module.tags.tags

}


data "aws_iam_policy_document" "this" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["sagemaker.amazonaws.com"]
    }
  }
}

################################################################################
# Security group
################################################################################

module "sagemaker_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name}-sagemaker"
  description = "Security group for Sagemaker"
  vpc_id      = module.vpc.vpc_id

  ingress_with_cidr_blocks = [
    {
      rule        = "https-443-tcp"
      description = "VPC CIDR HTTPS"
      cidr_blocks = join(",", module.vpc.private_subnets_cidr_blocks)
    },
  ]
  ingress_with_self = [
    {
      description = "All ingress within security group"
      from_port   = 8192
      to_port     = 65535
      protocol    = "tcp"
    }
  ]

  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      description = "All egress"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]

  tags = module.tags.tags
}

################################################################################
# S3 Bucket w/ Data Set
################################################################################

data "aws_caller_identity" "current" {}

locals {
    account_id = data.aws_caller_identity.current.account_id
}

output "account_id" {
  value = local.account_id
}

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket = "${local.name}-${local.account_id}"

  # Allow deletion of non-empty bucket
  # NOTE: This is enabled for example usage only, you should not enable this for production workloads
  force_destroy = true

  attach_deny_insecure_transport_policy = true
  attach_require_latest_tls_policy      = true

  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = module.tags.tags
}

resource "null_resource" "s3_data" {
  provisioner "local-exec" {
    command = <<-EOT
        aws s3 sync notebooks s3://${module.s3_bucket.s3_bucket_id}/notebooks/ && \
        curl https://cdn.openai.com/API/examples/data/vector_database_wikipedia_articles_embedded.zip --output embeddings.zip && \
        unzip embeddings.zip -d "embeddings_data" && \
        aws s3 sync embeddings_data s3://${module.s3_bucket.s3_bucket_id}/articles/
    EOT
  }
}