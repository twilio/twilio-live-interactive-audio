terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  account_id  = "897837310411"
  github_repo = "twilio/twilio-live-interactive-audio"
  test_bucket = "cpp-test-artifacts"

  # Only workflow runs on a branch (any branch) in this repo can assume the role.
  # Excludes tags, environments, and pull_request events. Forks cannot get an
  # OIDC token from GitHub at all, so the trust boundary is "anyone with write
  # access to the repo" — same as a private repo.
  oidc_sub_pattern = "repo:${local.github_repo}:ref:refs/heads/*"
}

# GitHub's OIDC provider is a per-AWS-account singleton. If Terraform errors
# with "no matching provider found", it hasn't been registered in this account
# yet — swap this `data` block for an `aws_iam_openid_connect_provider` resource
# (thumbprint 6938fd4d98bab03faadb97b34396831e3780aea1, client_id_list = ["sts.amazonaws.com"])
# and apply once, then switch back.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.oidc_sub_pattern]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "github" {
  name               = "twilio-live-interactive-audio-github-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  description        = "GitHub Actions OIDC role for ${local.github_repo}. Read-only on s3://${local.test_bucket} for pulling rtc-cpp test artifacts."
}

data "aws_iam_policy_document" "test_artifacts_read" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${local.test_bucket}/*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.test_bucket}"]
  }
}

resource "aws_iam_role_policy" "test_artifacts_read" {
  name   = "test-artifacts-read"
  role   = aws_iam_role.github.id
  policy = data.aws_iam_policy_document.test_artifacts_read.json
}

output "role_arn" {
  value       = aws_iam_role.github.arn
  description = "Set this as role-to-assume on the aws-actions/configure-aws-credentials step in the GitHub Actions workflow."
}
