locals {
  usage_metrics = yamldecode(data.local_file.metrics.content)["dashboard_data"]["usage"]
  filtered_usage_metrics = flatten([
    for service_name, id in local.usage_metrics : [
      for region in var.regions : [
        {
          type = "metric"
          properties = {
            region = region
            period = 300
            view   = "timeSeries"
            title  = format("%s: %s", service_name, region)
            yAxis = {
              left = {
                label     = "Quota usage percentage"
                min       = 0
                max       = 100
                showUnits = false
              }
            }
            metrics = concat([
              for id, metric_config in id : flatten([
                [
                  "AWS/Usage", metric_config["metric_name"], "Class", metric_config["dimensions"]["Class"], "Resource", metric_config["dimensions"]["Resource"], "Service", metric_config["dimensions"]["Service"], "Type", metric_config["dimensions"]["Type"],
                  { id = metric_config["dashboard_query_id"], region = region, visible = false, stat = metric_config["statistic"] }
                ]
              ])
              ],
              [for id, metric_config in id : [
                { expression = "(${metric_config["dashboard_query_id"]}/SERVICE_QUOTA(${metric_config["dashboard_query_id"]}))*100", label = format("%s: %s", service_name, metric_config["dimensions"]["Resource"]), region = region }
              ]]
            )
          }
        }
      ]
    ] if !contains(var.disabled_services, service_name)
  ])

}
