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
