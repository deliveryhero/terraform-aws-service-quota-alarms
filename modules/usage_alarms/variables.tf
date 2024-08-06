variable "disabled_services" {
  description = "List of services to disable. See main.tf for list"
  default     = []
  type        = list(string)
}

variable "cloudwatch_alarm_actions" {
  description = "Actions for all cloudwatch alarms. e.g. an SNS topic ARN"
  default     = []
  type        = list(string)
}

variable "enabled" {
  description = "If set to false no cloudwatch alarms will be created"
  default     = true
  type        = bool
}

variable "alarm_name_prefix" {
  description = "A string prefix for all cloudwatch alarms"
  default     = "service-quotas-"
  type        = string
}

variable "cloudwatch_alarm_threshold" {
  description = "The threshold for all cloudwatch alarms. This is a percentage of the limit so should be between 1-100"
  default     = 80
  type        = number
}

variable "tags" {
  description = "Tags to add to all cloudwatch alarms"
  type        = map(string)
  default     = {}
}

variable "dp_services" {
  description = "AWS Usage metrics to monitor"
  type        = map(map(list(string)))
  default     = {}
}
