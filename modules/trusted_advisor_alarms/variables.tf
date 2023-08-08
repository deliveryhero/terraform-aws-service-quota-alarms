variable "disabled_services" {
  description = "List of services to disable"
  default     = []
  type        = list(string)
}

variable "cloudwatch_alarm_actions" {
  default = []
  type    = list(string)
}

variable "enabled" {
  default = true
  type    = bool
}

variable "regions" {
  default = []
  type    = list(string)
}

variable "alarm_name_prefix" {
  default = "service-quotas-"
  type    = string
}

variable "cloudwatch_alarm_threshold" {
  default = 80
  type    = number
}

variable "tags" {
  type    = map(string)
  default = {}
}
