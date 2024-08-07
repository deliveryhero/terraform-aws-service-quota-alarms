
locals {
  service_limits = {
    # Format:
    #   <service name> = {
    #     <limit class> = [<service limit>]
    #   }
    #
    # Note:
    #  Some metrcs do not support the SERVICE_QUOTA query function yet so are not listed here
    #
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
      "Standard/Spot"     = [
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

  # for region in var.regions : region => [for metric in local.metrics_normalized_all : metric if metric.region == region && metric.service_name == service_name]

  service_limit_classes = flatten(
    [
      for service_name, data in local.service_limits : [
        for class, limits in data : [
          for resource in limits : {
            alarm_name   = format("%s%s-%s%s", var.alarm_name_prefix, replace(service_name, "/[\\W_]+/", ""), class == "None" ? "" : format("%s-", class), resource)
            service_name = service_name
            class        = class
            resource     = resource
          }
        ]
      ] if !contains(var.disabled_services, service_name)
    ]
  )

  resources = {
    for item in local.service_limit_classes : item.alarm_name => {
      service_name = item.service_name
      class        = item.class
      resource     = item.resource
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "main" {
  for_each            = var.enabled ? local.resources : {}
  alarm_actions       = var.cloudwatch_alarm_actions
  alarm_description   = "Service '${each.value.service_name}' quota '${each.value.resource}' (CloudWatch SERVICE_QUOTA) busage too high"
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
        "Class"    = each.value["class"]
        "Resource" = each.value["resource"]
        "Service"  = each.value["service_name"]
        "Type"     = startswith(each.value["resource"], "CryptographicOperations") ? "API" : "Resource"
      }
      metric_name = startswith(each.value["resource"], "CryptographicOperations") ? "CallCount" : "ResourceCount"
      namespace   = "AWS/Usage"
      period      = 300
      stat        = each.value["resource"] == "NumberOfMessagesPublishedPerAccount" ? "Sum" : "Maximum"
    }
  }
}
