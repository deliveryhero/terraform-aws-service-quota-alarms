locals {
  data_file_path = var.metric_data_file == null ? "${path.module}/supported-metrics.yaml" : var.metric_data_file

  usage_widget_header = {
    type   = "text"
    width  = 24
    height = 2
    properties = {
      "markdown" : "# Usage metrics \n### These metrics come from the `AWS/Usage` namespace \n"
    }
  }

  trusted_advisor_regional_widget_header = {
    type   = "text"
    width  = 24
    height = 2
    properties = {
      "markdown" : "# TrustedAdvisor metrics: regional \n### These metrics come from the `AWS/TrustedAdvisor` namespace \n"
    }
  }

  trusted_advisor_global_widget_header = {
    type   = "text"
    width  = 24
    height = 2
    properties = {
      "markdown" : "# TrustedAdvisor metrics: global \n### These metrics come from the `AWS/TrustedAdvisor` namespace \n"
    }
  }
}


data "local_file" "metrics" {
  filename = local.data_file_path
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "ServiceQuotaUsage"
  dashboard_body = jsonencode({ widgets = concat([local.usage_widget_header], local.filtered_usage_metrics, [local.trusted_advisor_regional_widget_header], local.filtered_regional_metrics, [local.trusted_advisor_global_widget_header], local.filtered_global_metrics) })
}
