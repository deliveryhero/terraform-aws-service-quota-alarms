locals {
  trusted_advisor_global_service_limits = {
    IAM = [
      "Policies",
      "Groups",
      "Users",
      "Instance profiles",
      "Server certificates",
      "Roles",
    ]
    Route53 = [
      "Route 53 Max Health Checks",
      "Route 53 Traffic Policy Instances",
      "Route 53 Hosted Zones",
      "Route 53 Reusable Delegation Sets",
      "Route 53 Traffic Policies",
    ]
  }

  trusted_advisor_global_metrics_normalized_all = flatten([
    for service_name, limits in local.trusted_advisor_global_service_limits : [
      for resource in limits : {
        resource     = resource
        service_name = service_name
        id           = lower(replace(format("%s%s", service_name, resource), "/[\\W_]+/", ""))
        label        = format("%s: %s", service_name, resource)
      }
    ] if !contains(var.disabled_services, service_name)
  ])

  trusted_advisor_global_metrics_normalized_service_region = {
    for service_name, limits in local.trusted_advisor_global_service_limits : service_name => {
      for region in ["global"] : region => [for metric in local.trusted_advisor_global_metrics_normalized_all : metric if metric.service_name == service_name]
    }
  }

  trusted_advisor_global_dashboard_widgets = flatten([
    for service_name, region_data in local.trusted_advisor_global_metrics_normalized_service_region : [
      for region, metrics in region_data : [
        {
          type = "metric"
          properties = {
            stat   = "Sum"
            region = "us-east-1"
            period = 300
            view   = "timeSeries"
            title  = format("%s: global", service_name)
            yAxis = {
              left = {
                label     = "Quota usage percentage"
                min       = 0
                max       = 100
                showUnits = false
              }
            }
            metrics = concat([
              for metric in metrics : flatten([
                [
                  "AWS/TrustedAdvisor", "ServiceLimitUsage", "ServiceName", metric["service_name"], "ServiceLimit", metric["resource"], "Region", "-",
                  { id = metric["id"], visible = false }
                ]
              ])
              ],
              [for metric in metrics : [
                { expression = "${metric.id}*100", label = metric["label"] }
              ]]
            )
          }
        }
      ]
    ]
  ])
}
