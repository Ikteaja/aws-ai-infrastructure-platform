resource "aws_iam_openid_connect_provider" "github" {
  provider        = aws.iam
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["ab9d0263244dd0326eb67015705a667e79cfe998"]
  tags = {
    Project     = "healthcare-operations-assistant"
    Environment = "shared"
    ManagedBy   = "manual"
    Name        = "github-actions-oidc"
  }
  lifecycle {
    prevent_destroy = true
  }
}
