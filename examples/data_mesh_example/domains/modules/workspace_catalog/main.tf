# This module create catalog related resources for a workspace.
# Ref. https://registry.terraform.io/providers/databricks/databricks/latest/docs/guides/unity-catalog

# =============================================================================
# Create a storage credential for external access
# =============================================================================
data "aws_caller_identity" "current" {}

resource "databricks_storage_credential" "external" {
  name = "${var.prefix}-external-access"
  aws_iam_role {
    role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.prefix}-external-access" //cannot reference aws_iam_role directly, as it will create circular dependency
  }
  comment = "Managed by TF"
}

# =============================================================================
# Create a storage credential for external access
# =============================================================================
resource "aws_s3_bucket" "external" {
  bucket = "${var.prefix}-external"
  acl    = "private"
  // destroy all objects with bucket destroy
  force_destroy = true
  tags = merge(var.tags, {
    Name = "${var.prefix}-external"
  })
}

resource "aws_s3_bucket_versioning" "external_versioning" {
  bucket = aws_s3_bucket.external.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_public_access_block" "external" {
  bucket             = aws_s3_bucket.external.id
  ignore_public_acls = true
  depends_on         = [aws_s3_bucket.external]
}

data "aws_iam_policy_document" "passrole_for_uc" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = [databricks_storage_credential.external.aws_iam_role[0].unity_catalog_iam_arn]
      type        = "AWS"
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [databricks_storage_credential.external.aws_iam_role[0].external_id]
    }
  }
  statement {
    sid     = "ExplicitSelfRoleAssumption"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.prefix}-external-access"]
    }
  }
}

resource "aws_iam_policy" "external_data_access" {
  // Terraform's "jsonencode" function converts a
  // Terraform expression's result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "${aws_s3_bucket.external.id}-access"
    Statement = [
      {
        "Action" : [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        "Resource" : [
          aws_s3_bucket.external.arn,
          "${aws_s3_bucket.external.arn}/*"
        ],
        "Effect" : "Allow"
      },
      {
        "Action" : [
          "sts:AssumeRole"
        ],
        "Resource" : [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.prefix}-external-access"
        ],
        "Effect" : "Allow"
      },
    ]
  })
  tags = merge(var.tags, {
    Name = "${var.prefix}-unity-catalog external access IAM policy"
  })
}

resource "aws_iam_role" "external_data_access" {
  name                = "${var.prefix}-external-access"
  assume_role_policy  = data.aws_iam_policy_document.passrole_for_uc.json
  managed_policy_arns = [aws_iam_policy.external_data_access.arn]
  tags = merge(var.tags, {
    Name = "${var.prefix}-unity-catalog external access IAM role"
  })
}

# Work around to wait for the role to be created
resource "time_sleep" "wait_iam_role" {
  create_duration = "10s"
  depends_on      = [aws_iam_role.external_data_access]
}

# =============================================================================
# Create a databricks_external_location
# =============================================================================
resource "databricks_external_location" "this" {
  name            = "${aws_s3_bucket.external.id}_external_location"
  url             = "s3://${aws_s3_bucket.external.id}"
  credential_name = databricks_storage_credential.external.id
  comment         = "Managed by TF"
  depends_on      = [time_sleep.wait_iam_role]
}

# =============================================================================
# Create a catalog for the workspace
# =============================================================================
resource "databricks_catalog" "this" {
  name = var.catalog_name
  storage_root = "s3://${aws_s3_bucket.external.id}/${var.catalog_name}"
  isolation_mode = "ISOLATED"
  comment = "Managed by TF"
}
