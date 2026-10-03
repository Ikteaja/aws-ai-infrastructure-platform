# A repository stores versions of one application's image;
resource "aws_ecr_repository" "this" {
  for_each = var.repositories
  name     = "${var.name_prefix}/${each.key}"

  # A commit tag cannot be overwritten with different image contents.
  image_tag_mutability = "IMMUTABLE"

  # Refuse repository deletion while images remain; cleanup must be deliberate.
  force_delete = false

  # ECR creates service grants on this key. The apply role needs KMS grant permissions.
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.images.arn
  }

  # Basic scan-on-push is asynchronous and complements the existing Trivy CI gate.
  # This module does not change the account-wide registry scanning configuration.
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name      = "${var.name_prefix}/${each.key}"
    Component = "container-registry"
    Service   = each.key
  })
}
