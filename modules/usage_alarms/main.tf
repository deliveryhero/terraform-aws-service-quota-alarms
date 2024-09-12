
locals {
  metrics = yamldecode(file("${path.module}/supported-metrics.yaml"))["usage_metrics"]
}

resource "aws_cloudwatch_metric_alarm" "main" {
  for_each            = var.enabled ? local.metrics : {}
  alarm_actions       = var.cloudwatch_alarm_actions
  alarm_description   = "Service '${each.value.dimensions.Service}' quota '${each.value.dimensions.Resource}' (CloudWatch SERVICE_QUOTA) usage too high"
  alarm_name          = each.key
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
      dimensions = {
        "Class"    = each.value["dimensions"]["Class"]
        "Resource" = each.value["dimensions"]["Resource"]
        "Service"  = each.value["dimensions"]["Service"]
        "Type"     = each.value["dimensions"]["Type"]
      }
      metric_name = each.value["metric_name"]
      namespace   = each.value["namespace"]
      period      = 300
      stat        = each.value["statistic"]
    }
  }
}
