resource "aws_iam_role" "ecr_image_publisher" {
  provider             = aws.iam
  name                 = "healthops-dev-ecr-image-publisher"
  path                 = "/"
  description          = "Allows trusted GitHub Actions runs to publish dev application images."
  max_session_duration = 3600

  assume_role_policy = jsonencode(jsondecode(file(
    "${path.module}/policies/publisher/trust.json"
  )))

  tags = {
    Name        = "healthops-dev-ecr-image-publisher"
    Project     = "healthcare-operations-assistant"
    Environment = "dev"
    Component   = "image-publisher"
    ManagedBy   = "Terraform"
    Owner       = "Ikteaja"
  }
}

resource "aws_iam_role_policy" "ecr_image_publisher" {
  provider = aws.iam
  name     = "healthops-dev-ecr-image-publisher"
  role     = aws_iam_role.ecr_image_publisher.name
  policy = jsonencode(jsondecode(file(
    "${path.module}/policies/publisher/ecr-image-publisher.json"
  )))
}
