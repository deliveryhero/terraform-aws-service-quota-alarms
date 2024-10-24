locals {
  data_file_path   = var.metric_data_file == null ? "${path.module}/supported-metrics.yaml" : var.metric_data_file
  regional_metrics = yamldecode(data.local_file.metrics.content)["trusted_advisor_metrics_regional"]
  filtered_regional_metrics = flatten([
    for region in var.regions : [
      for alarm_name, config in local.regional_metrics : {
        alarm_name  = "${alarm_name}-${region}"
        statistic   = config["statistic"]
        metric_name = config["metric_name"]
        dimensions  = merge(config["dimensions"], { Region = region })
      } if !contains(var.disabled_services, config.dimensions["ServiceName"])
    ]
  ])

  global_metrics          = yamldecode(data.local_file.metrics.content)["trusted_advisor_metrics_global"]
  filtered_global_metrics = { for alarm_name, config in local.global_metrics : alarm_name => config if !contains(var.disabled_services, config.dimensions["ServiceName"]) }
}

data "local_file" "metrics" {
  filename = local.data_file_path
}

resource "aws_cloudwatch_metric_alarm" "regional" {
  for_each            = var.enabled ? { for m in local.filtered_regional_metrics : m.alarm_name => m } : {}
  alarm_actions       = var.cloudwatch_alarm_actions
  alarm_description   = "Service '${each.value.dimensions.ServiceName}' quota '${each.value.dimensions.ServiceLimit}' (TrustedAdvisor regional) usage too high in region '${each.value.dimensions.Region}'"
  alarm_name          = "${var.alarm_name_prefix}-${each.key}"
  comparison_operator = "GreaterThanThreshold"
  datapoints_to_alarm = 1
  evaluation_periods  = 1
  metric_name         = each.value.metric_name
  namespace           = "AWS/TrustedAdvisor"
  ok_actions          = var.cloudwatch_alarm_actions
  period              = 300
  statistic           = each.value.statistic
  tags                = var.tags
  threshold           = var.cloudwatch_alarm_threshold / 100
  treat_missing_data  = "ignore"
  dimensions          = each.value.dimensions
}

resource "aws_cloudwatch_metric_alarm" "global" {
  for_each            = var.enabled ? local.filtered_global_metrics : {}
  alarm_actions       = var.cloudwatch_alarm_actions
  alarm_description   = "Service '${each.value.dimensions.ServiceName}' quota '${each.value.dimensions.ServiceLimit}' (TrustedAdvisor global) usage too high"
  alarm_name          = "${var.alarm_name_prefix}-${each.key}"
  comparison_operator = "GreaterThanThreshold"
  datapoints_to_alarm = 1
  evaluation_periods  = 1
  metric_name         = each.value.metric_name
  namespace           = "AWS/TrustedAdvisor"
  ok_actions          = var.cloudwatch_alarm_actions
  period              = 300
  statistic           = each.value.statistic
  tags                = var.tags
  threshold           = var.cloudwatch_alarm_threshold / 100
  treat_missing_data  = "ignore"
  dimensions          = each.value.dimensions
}
