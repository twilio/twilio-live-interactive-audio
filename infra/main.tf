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

  # The `refs/heads/*` sub pattern below is the SOLE control excluding fork PRs
  # from assuming this role. Fork PRs DO get an OIDC token from GitHub — the
  # exclusion works because their `sub` claim is `repo:<owner>/<repo>:pull_request`
  # (not `ref:refs/heads/...`), which does not match this pattern.
  #
  # DO NOT widen this to `repo:${local.github_repo}:*` without a security review.
  # On a public repo, a `:*` wildcard would grant this role to any fork PR run.
  # Any expansion (tags, environments, workflow_ref) must be added as explicit,
  # narrowly-scoped alternatives — never as a wildcard.
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
  # Read-only on the packages/ prefix rtc-cpp uploads to. GetObjectVersion is
  # required for the dispatch path, which downloads with `--version-id`.
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]
    resources = ["arn:aws:s3:::${local.test_bucket}/packages/*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${local.test_bucket}"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["packages/*", "packages/"]
    }
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
