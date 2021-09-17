variable "hub_account_id" {
  type        = string
  description = "(required) The ID of the hub account"
}

variable "org_account_id" {
  type        = string
  description = "(optional) The ID of the AWS Organizations account, required for hub"
  default = ""
}

variable "org_account_role_name" {
  type        = string
  description = "(optional) The AWS Organizations role name, required for hub"
  default = ""
}

variable "org_account_ou_name" {
  type        = string
  description = "(optional) The AWS Organizations Organizational Unit Name to list the child accounts, required for hub"
  default = ""
}

variable "spoke_account_role_name" {
  type        = string
  description = "(optional) The spoke account role name"
  default     = "g-secrets-sync-lambda"
}

variable "project" {
  type        = string
  description = "(optional) The project name used as a prefix for all resources"
  default     = "grace"
}

variable "appenv" {
  type        = string
  description = "(optional) The targeted application environment used in resource names (default: development)"
  default     = "development"
}

variable "region" {
  type        = string
  description = "(optional) The AWS region for executing the EC2 (default: us-east-1)"
  default     = "us-east-1"
}

variable "prefix" {
  type        = string
  description = "(optional) The name prefix used to signify a secret should be replicated (default: g-)"
  default     = "g-"
}

variable "is_hub" {
  type        = bool
  description = "(optional) Indicates whether this is the hub account (true) or a spoke account (false) (default: false)"
  default     = false
}

variable "source_file" {
  type        = string
  description = "(optional) The full or relative path to zipped binary of lambda handler"
  default     = "release/grace-secrets-sync-lambda.zip"
}