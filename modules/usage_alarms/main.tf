locals {
  data_file_path   = var.metric_data_file == null ? "${path.module}/supported-metrics.yaml" : var.metric_data_file
  metrics          = yamldecode(data.local_file.metrics.content)["usage"]
  filtered_metrics = { for alarm_name, config in local.metrics : alarm_name => config if !contains(var.disabled_services, config.dimensions["Service"]) || !contains(var.disabled_alarms, alarm_name) }
}

data "local_file" "metrics" {
  filename = local.data_file_path
}

resource "aws_cloudwatch_metric_alarm" "main" {
  for_each            = var.enabled ? local.filtered_metrics : {}
  alarm_actions       = var.cloudwatch_alarm_actions
  alarm_description   = "Service '${each.value.dimensions.Service}' quota '${each.value.dimensions.Resource}' quota usage too high"
  alarm_name          = "${var.alarm_name_prefix}-${each.key}"
  comparison_operator = "GreaterThanThreshold"
  datapoints_to_alarm = 1
  evaluation_periods  = 1
  ok_actions          = var.cloudwatch_alarm_actions
  tags                = var.tags
  threshold           = var.cloudwatch_alarm_threshold

  metric_query {
    expression  = "m1/SERVICE_QUOTA(m1)*100"
    id          = "e1"
    label       = "QuotaUsagePercentage"
    return_data = true
  }

  metric_query {
    id          = "m1"
    return_data = false

    metric {
      dimensions  = each.value["dimensions"]
      metric_name = each.value["metric_name"]
      namespace   = each.value["namespace"]
      period      = 300
      stat        = each.value["statistic"]
    }
  }
}
