# Only untagged images expire automatically; tagged releases remain available.
resource "aws_ecr_lifecycle_policy" "untagged" {
  for_each   = var.repositories
  repository = aws_ecr_repository.this[each.key].name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images after ${var.untagged_retention_days} days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = var.untagged_retention_days
      }
      action = { type = "expire" }
    }]
  })
}
