resource "aws_lambda_function" "lambda" {
  count                          = var.is_hub ? 1 : 0
  filename                       = var.source_file
  function_name                  = local.app_name
  description                    = "Synchronizes the prefixed secrets to child accounts under the specified OU"
  role                           = aws_iam_role.hub_role[0].arn
  handler                        = local.lambda_handler
  source_code_hash               = filebase64sha256(var.source_file)
  kms_key_arn                    = aws_kms_key.lambda[0].arn
  reserved_concurrent_executions = 1
  runtime                        = "go1.x"
  timeout                        = 900

  environment {
    variables = {
      REGION         = var.region
      PREFIX         = var.prefix
      ORG_ACCOUNT_ID = var.org_account_id
      ORG_ROLE_NAME  = var.org_account_role_name
      ORG_UNIT_NAME  = var.org_account_ou_name
      ROLE_NAME      = var.spoke_account_role_name
      KMS_KEY_ALIAS  = "alias/${var.spoke_account_role_name}"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.hub_policy]
}

# used to trigger lambda when prefixed secrets are updated
resource "aws_lambda_permission" "cloudwatch_invoke" {
  count         = var.is_hub ? 1 : 0
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.secretsmanager[0].arn
}
