variable "disabled_services" {
  description = "List of services to disable. See supported-metrics.yaml for list"
  default     = []
  type        = list(string)
}

variable "disabled_alarms" {
  description = "List of alarms to disable. See supported-metrics.yaml for list, it should be the YAML key, e.g. AWSTrustedAdvisor-ServiceLimitUsage-ActiveloadbalancersELB"
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

variable "regions" {
  description = "A list of AWS regions to create alarms for"
  default     = []
  type        = list(string)
}

variable "metric_data_file" {
  description = "Path to YAML file containing the metrics to create alarms for. By default the one contained in the module will be used."
  default     = null
  type        = string
}

variable "alarm_name_prefix" {
  description = "A string prefix for all cloudwatch alarms"
  default     = "ServiceQuota"
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
