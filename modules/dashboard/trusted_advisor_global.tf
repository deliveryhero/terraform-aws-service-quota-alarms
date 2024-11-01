locals {
  global_metrics = yamldecode(data.local_file.metrics.content)["dashboard_data"]["trusted_advisor_global"]
  filtered_global_metrics = flatten([
    for service_name, id in local.global_metrics : [
      {
        type = "metric"
        properties = {
          region = "us-east-1"
          period = 300
          view   = "timeSeries"
          title  = format("global: %s", service_name)
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
                "AWS/TrustedAdvisor", metric_config["metric_name"], "ServiceName", metric_config["dimensions"]["ServiceName"], "ServiceLimit", metric_config["dimensions"]["ServiceLimit"], "Region", "-",
                { id = metric_config["dashboard_query_id"], visible = false, stat = metric_config["statistic"] }
              ]
            ])
            ],
            [for id, metric_config in id : [
              { expression = "${metric_config["dashboard_query_id"]}*100", label = format("%s: %s", service_name, metric_config["dimensions"]["ServiceLimit"]) }
            ]]
          )
        }
      }
    ] if !contains(var.disabled_services, service_name)
  ])
}
