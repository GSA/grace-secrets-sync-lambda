data "aws_caller_identity" "current" {}

locals {
  app_name     = "${var.project}-${var.appenv}-secrets-sync-lambda"
  hub_app_name = "${var.hub_project_name}-${var.appenv}-secrets-sync-lambda"

  account_id     = data.aws_caller_identity.current.account_id
  lambda_handler = "grace-secrets-sync-lambda"
}