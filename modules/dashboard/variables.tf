variable "regions" {
  description = "A list of AWS regions to create dashboard panels for"
  default     = []
  type        = list(string)
}

variable "disabled_services" {
  description = "List of services to disable"
  default     = []
  type        = list(string)
}

variable "metric_data_file" {
  description = "Path to YAML file containing the metrics to create alarms for. By default the one contained in the module will be used."
  default     = null
  type        = string
}
