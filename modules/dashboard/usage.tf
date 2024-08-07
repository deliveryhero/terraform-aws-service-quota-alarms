locals {
  usage_service_limits = {
    AutoScaling = {
      None = [
        "NumberOfAutoScalingGroup"
      ]
    }
    CloudWatch = {
      None = [
        "InsightRule"
      ]
    }
    DynamoDB = {
      None = [
        "AccountProvisionedReadCapacityUnits",
        "AccountProvisionedWriteCapacityUnits",
      ]
    }
    EC2 = {
      "Standard/OnDemand" = [
        "vCPU"
      ]
      "Standard/Spot" = [
        "vCPU"
      ]
    }
    "Elastic Load Balancing" = {
      None = [
        "ApplicationLoadBalancersPerRegion",
        "CertificatesPerApplicationLoadBalancer",
        "CertificatesPerNetworkLoadBalancer",
        "ClassicLoadBalancersPerRegion",
        "ListenersPerApplicationLoadBalancer",
        "ListenersPerClassicLoadBalancer",
        "ListenersPerNetworkLoadBalancer",
        "NetworkLoadBalancersENIsPerVPC",
        "NetworkLoadBalancersPerRegion",
        "RegisteredInstancesPerClassicLoadBalancer",
        "RoutingRulesPerApplicationLoadBalancer",
        "TargetGroupsPerApplicationLoadBalancer",
        "TargetGroupsPerRegion",
        "TargetsPerApplicationLoadBalancer",
        "TargetsPerAvailabilityZonePerNetworkLoadBalancer",
        "TargetsPerNetworkLoadBalancer",
        "TargetsPerTargetGroupPerRegion",
      ]
    }
    Firehose = {
      None = [
        "DeliveryStreams"
      ]
    }
    KMS = {
      None = [
        "CryptographicOperationsRsa",
        "CryptographicOperationsSymmetric"
      ]
    }
    SNS = {
      None = [
        "NumberOfMessagesPublishedPerAccount"
      ]
    }
  }

  usage_metrics_normalized_all = flatten([
    for region in var.regions : [
      for service_name, data in local.usage_service_limits : [
        for class, limits in data : [
          for resource in limits : {
            class        = class
            resource     = resource
            region       = region
            service_name = service_name
            id           = lower(replace(format("%s%s%s", service_name, class, resource), "/[\\W_]+/", ""))
            label        = format("%s (%s): %s", service_name, class, resource)
          }
        ]
      ] if !contains(var.disabled_services, service_name)
    ]
  ])

  usage_metrics_normalized_service_region = {
    for service_name, data in local.usage_service_limits : service_name => {
      for region in var.regions : region => [for metric in local.usage_metrics_normalized_all : metric if metric.region == region && metric.service_name == service_name]
    }
  }

  usage_dashboard_widgets = flatten([
    for service_name, region_data in local.usage_metrics_normalized_service_region : [
      for region, metrics in region_data : [
        {
          type = "metric"
          properties = {
            stat   = "Maximum"
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
              for metric in metrics : flatten([
                [
                  "AWS/Usage", "ResourceCount", "Class", metric["class"], "Resource", metric["resource"], "Service", metric["service_name"], "Type", "Resource",
                  { id = metric["id"], region = metric["region"], visible = false, "stat" = metric["resource"] == "NumberOfMessagesPublishedPerAccount" ? "Sum" : "Maximum" }
                ]
              ])
              ],
              [for metric in metrics : [
                { expression = "(${metric.id}/SERVICE_QUOTA(${metric.id}))*100", label = metric["label"], region = metric["region"] }
              ]]
            )
          }
        }
      ]
    ]
  ])
}
