variable "common_tags" {
  type        = map(any)
  default     = null
  description = "map of tags"
}
variable "flow_logs" {
  type        = bool
  default     = false
  description = "Used to enable flow logs"
}
variable "cidr_block" {
  type        = string
  description = "VPC CIDR block"
}
variable "enable_dns_hostnames" {
  type    = bool
  default = true
}
variable "enable_dns_support" {
  type    = bool
  default = true
}
variable "enable_classiclink" {
  type    = bool
  default = false
}
variable "name" {
  type        = string
  default     = ""
  description = "AWS special 'Name' tag"
}
variable "tag_prefix" {
  type        = string
  default     = ""
  description = "'Name' tag prefix, used for resource naming."
}
variable "kms_key_id" {
  type        = string
  default     = null
  description = "Key ID for flow logs to use. If this is left as null, then the VPC flow logs will use the default key policy: https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html."
}