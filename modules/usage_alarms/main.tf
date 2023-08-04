
locals {
  service_limits = {
    # Format:
    #   <service name> = {
    #     <limit class> = [<service limit>]
    #   }
    #
    # Note:
    #  A commented service limit means that the metric is in cloudwatch but does not support
    #  the SERVICE_QUOTA query function yet. Perhaps support will be added by AWS soon.
    #
    AutoScaling = {
      None = ["NumberOfAutoScalingGroup"]
    }
    CloudWatch = {
      None = ["InsightRule"]
    }
    DMS = {
      None = [
        # "AllocatedStorage",
        # "Endpoints",
        # "EndpointsPerInstance",
        # "ReplicationInstances",
        # "ReplicationSubnetGroups",
        # "ReplicationTasks",
        # "SubnetsPerReplicationSubnetGroup",
      ]
    }
    DynamoDB = {
      None = [
        "AccountProvisionedWriteCapacityUnits",
        "AccountProvisionedReadCapacityUnits",
        # "TableCount",
      ]
    }
    EC2 = {
      "Standard/OnDemand" = ["vCPU"]
      "Standard/Spot"     = ["vCPU"]
    }
    "Elastic Load Balancing" = {
      None = [
        "TargetGroupsPerApplicationLoadBalancer",
        "ListenersPerApplicationLoadBalancer",
        "TargetsPerTargetGroupPerRegion",
        "TargetsPerAvailabilityZonePerNetworkLoadBalancer",
        "TargetsPerApplicationLoadBalancer",
        "ListenersPerClassicLoadBalancer",
        "RoutingRulesPerApplicationLoadBalancer",
        "RegisteredInstancesPerClassicLoadBalancer",
        "TargetsPerNetworkLoadBalancer",
        "ClassicLoadBalancersPerRegion",
        "ListenersPerNetworkLoadBalancer",
        "NetworkLoadBalancersENIsPerVPC",
        "CertificatesPerApplicationLoadBalancer",
        "TargetGroupsPerRegion",
        "CertificatesPerNetworkLoadBalancer",
        "ApplicationLoadBalancersPerRegion",
        "NetworkLoadBalancersPerRegion",
      ]
    }
    Firehose = {
      None = ["DeliveryStreams"]
    }
    RDS = {
      None = [
        # "ManualClusterSnapshots",
        # "DBClusterParameterGroups",
        # "ManualSnapshots",
        # "DBInstances",
        # "DBClusters",
        # "DBParameterGroups",
        # "DBSubnetGroups",
        # "AllocatedStorage",
      ]
    }
    SNS = {
      None = ["NumberOfMessagesPublishedPerAccount"]
    }
    SageMaker = {
      None = [
        # "notebook-instance/total_volume_size_in_gb",
        "notebook-instance/total_count",
        "notebook-instance/ml.t2.medium",
      ]
    }
    "Secrets Manager" = {
      None = [
        # "SecretCount"
      ]
    }
    SNS = {
      None = ["NumberOfMessagesPublishedPerAccount"]
    }
  }

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
      ]
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
  alarm_description   = "${each.value.service_name} ${each.value.resource} quota usage too high"
  alarm_name          = each.key
  comparison_operator = "GreaterThanThreshold"
  datapoints_to_alarm = 1
  evaluation_periods  = 1
  tags                = var.cloudwatch_alarm_tags
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
        "Type"     = "Resource"
      }
      metric_name = "ResourceCount"
      namespace   = "AWS/Usage"
      period      = 3600
      stat        = "Average"
    }
  }
}
