resource "aws_cloudwatch_event_rule" "secretsmanager" {
  count       = var.is_hub ? 1 : 0
  name        = "secretsmanager_events"
  description = "matches all secret modification related API events when the specified name prefix is matched"

  event_pattern = <<EOF
{
  "source": [
    "aws.secretsmanager"
  ],
  "detail-type": [
    "AWS API Call via CloudTrail"
  ],
  "detail": {
    "eventSource": [
      "secretsmanager.amazonaws.com"
    ],
    "eventName": [
      "CreateSecret",
      "PutSecretValue",
      "RestoreSecret",
      "UpdateSecret"
    ],
    "requestParameters": {
      "secretId": ["${var.prefix}*"]
    }
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "secretsmanager" {
  count = var.is_hub ? 1 : 0
  rule  = aws_cloudwatch_event_rule.secretsmanager[0].name
  arn   = aws_lambda_function.lambda[0].arn
}