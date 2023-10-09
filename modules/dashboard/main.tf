locals {
  usage_widget_header = {
    type   = "text"
    width  = 24
    height = 2
    properties = {
      "markdown" : "# Usage metrics \n### These metrics come from the `AWS/Usage` namespace [here](https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#metricsV2?graph=~()&query=~'*7bAWS*2fUsage*2cClass*2cResource*2cService*2cType*7d*20AWS*2fUsage*20MetricName*3dResourceCount) \n"
    }
  }

  trusted_advisor_widget_header = {
    type   = "text"
    width  = 24
    height = 2
    properties = {
      "markdown" : "# TrustedAdvisor metrics \n### These metrics come from the `AWS/TrustedAdvisor` namespace [here](https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#metricsV2?graph=~()&query=~'*7bAWS*2fTrustedAdvisor*2cRegion*2cServiceLimit*2cServiceName*7d*20MetricName*3dServiceLimitUsage) \n"
    }
  }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "ServiceQuotaUsage"
  dashboard_body = jsonencode({ widgets = concat([local.usage_widget_header], local.usage_dashboard_widgets, [local.trusted_advisor_widget_header], local.trusted_advisor_dashboard_widgets, local.trusted_advisor_global_dashboard_widgets) })
}
