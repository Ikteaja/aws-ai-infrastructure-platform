# Store VPC network metadata in CloudWatch Logs for troubleshooting and audit.
# Flow Logs do not capture packet payloads. Dev retention is intentionally 30 days.
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# Encrypt this log group with a dedicated, automatically rotated customer key.
# KMS key policies use Resource "*" to refer to the key they are attached to.
data "aws_iam_policy_document" "flow_logs_kms" {
  # checkov:skip=CKV_AWS_356:KMS key policies require Resource *; this policy is attached to one key and limits principals and CloudWatch Logs context.
  statement {
    sid    = "EnableAccountKeyAdministration"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }

    actions = [
      "kms:CancelKeyDeletion",
      "kms:DescribeKey",
      "kms:DisableKey",
      "kms:EnableKey",
      "kms:EnableKeyRotation",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListResourceTags",
      "kms:PutKeyPolicy",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:UpdateKeyDescription",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [data.aws_region.current.region]
    }
  }

  statement {
    sid    = "AllowCloudWatchLogsForThisGroup"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.region}.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]

    condition {
      test     = "ArnEquals"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vpc/${var.name}/flow-logs"
      ]
    }
  }
}

resource "aws_kms_key" "vpc_flow_logs" {
  description             = "Encryption key for ${var.name} VPC Flow Logs"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.flow_logs_kms.json

  tags = merge(var.tags, {
    Name      = "${var.name}-vpc-flow-logs-key"
    Component = "network-flow-logs"
  })
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name       = "/aws/vpc/${var.name}/flow-logs"
  kms_key_id = aws_kms_key.vpc_flow_logs.arn

  # This is intentionally shorter than the production baseline for dev.
  # Revisit before production; this exception does not meet a 365-day policy.
  # checkov:skip=CKV_AWS_338:Dev Flow Logs are intentionally retained for 30 days to limit cost; increase to 365 before production.
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "${var.name}-vpc-flow-logs"
  })
}

# VPC Flow Logs assumes this role to publish records to the log group.
data "aws_iam_policy_document" "flow_logs_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name               = "${var.name}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_assume_role.json

  tags = var.tags
}

# Limit log publishing to this flow-log group; DescribeLogGroups requires "*".
data "aws_iam_policy_document" "flow_logs_publish" {
  statement {
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"]
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name   = "${var.name}-vpc-flow-logs-publish"
  role   = aws_iam_role.vpc_flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs_publish.json
}

# Capture accepted and rejected traffic metadata for every interface in the VPC.
resource "aws_flow_log" "vpc" {
  vpc_id                   = aws_vpc.this.id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn             = aws_iam_role.vpc_flow_logs.arn
  max_aggregation_interval = 600

  depends_on = [aws_iam_role_policy.vpc_flow_logs]

  tags = merge(var.tags, {
    Name = "${var.name}-vpc-flow-log"
  })
}