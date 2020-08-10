# GRACE Secrets Sync [![GoDoc](https://godoc.org/github.com/GSA/grace-secrets-sync-lambda?status.svg)](https://godoc.org/github.com/GSA/grace-secrets-sync-lambda) [![Go Report Card](https://goreportcard.com/badge/gojp/goreportcard)](https://goreportcard.com/report/github.com/GSA/grace-secrets-sync-lambda) [![CircleCI](https://circleci.com/gh/GSA/grace-secrets-sync-lambda.svg?style=shield)](https://circleci.com/gh/GSA/grace-secrets-sync-lambda)

GRACE Secrets Sync is a lambda function that enables synchronizing secrets from one central account into any number of sub-accounts that exist beneath a particular OU. To signify a secret should be replicated a prefix is implemented to differentiate the secret name.

## Repository contents

- **./**: Terraform module to deploy and configure Lambda function, S3 Bucket and IAM roles and policies
- **lambda**: Go code for Lambda function

## Terraform Module Inputs

| Name | Description | Type | Default | Required |
|------|-------------|:----:|:-----:|:-----:|
| hub_account_id | The AWS Account ID of the hub account | string | `""` | yes |
| org_account_id | The AWS Account ID of the AWS Organizations account | string | `""` | yes |
| org_account_role_name | The IAM Role name used to query AWS Organizations | string | `""` | yes |
| org_account_ou_name | The name of the AWS Organizations Organizational Unit | string | `""` | yes |
| project | The project name used as a prefix for all resources | string | `"grace"` | no |
| appenv | The targeted application environment used in resource names | string | `"development"` | no |
| region | The AWS region for executing the EC2 | string | `"us-east-1"` | no |
| prefix | The name prefix used to signify a secret should be replicated | string | `"g-"` | no |
| is_hub | Indicates whether this is the hub account (true) or a spoke account (false) | bool | `false` | no |
| source_file | The full or relative path to zipped binary of lambda handler | string | `"../release/grace-secrets-sync-lambda.zip"` | no |

[top](#top)

## Environment Variables

### Lambda Environment Variables

| Name                 | Description |
| -------------------- | ------------|
| REGION               | (optional) Region used for EC2 instances (default: us-east-1) |
| PREFIX               | (optional) Name prefix used for listing secrets in the hub (default: g-) |
| ORG_ACCOUNT_ID       | (optional) The Account ID of the AWS Organizations account |
| ORG_ROLE_NAME        | (optional) The IAM Role name of the AWS Organizations access role |
| ORG_UNIT_NAME        | (optional) The name of the AWS Organizations OU to list child accounts |
| ROLE_NAME            | (optional) The IAM Role name used by the lambda in child-accounts to update secrets |
| KMS_KEY_ALIAS        | (optional) The KMS Key Alias of the KMS Key in child-accounts |


[top](#top)

## Public domain

This project is in the worldwide [public domain](LICENSE.md). As stated in [CONTRIBUTING](CONTRIBUTING.md):

> This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).
>
> All contributions to this project will be released under the CC0 dedication. By submitting a pull request, you are agreeing to comply with this waiver of copyright interest.