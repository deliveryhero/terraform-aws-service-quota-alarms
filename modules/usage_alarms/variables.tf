variable "cloudwatch_alarm_actions" {
  default = []
  type    = list(string)
}

variable "enabled" {
  default = true
  type    = bool
}

variable "alarm_name_prefix" {
  default = "service-quotas-"
  type    = string
}

variable "cloudwatch_alarm_threshold" {
  default = 80
  type    = number
}

variable "cloudwatch_alarm_tags" {
  type    = map(string)
  default = {}
}
