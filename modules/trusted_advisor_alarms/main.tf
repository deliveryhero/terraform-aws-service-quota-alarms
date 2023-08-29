locals {
  service_limits = {
    #   <service name> = [<service limit>]
    AutoScaling = [
      "Auto Scaling groups",
      "Launch configurations"
    ]
    CloudFormation = [
      "Stacks"
    ]
    DynamoDB = [
      "DynamoDB Read Capacity",
      "DynamoDB Write Capacity"
    ]
    EBS = [
      "Active snapshots",
      "Cold HDD (sc1) volume storage (TiB)",
      "General Purpose SSD (gp2) volume storage (TiB)",
      "General Purpose SSD (gp3) volume storage",
      "Magnetic (standard) volume storage (TiB)",
      "Provisioned IOPS (SSD) storage (TiB)",
      "Provisioned IOPS SSD (io2) Volume Storage",
      "Provisioned IOPS",
      "Throughput Optimized HDD (st1) volume storage (TiB)",
    ]
    EC2 = [
      "Elastic IP addresses (EIPs)",
      "On-Demand instances"
    ]
    ELB = [
      "Active Application Load Balancers",
      "Active Network Load Balancers",
      "Active load balancers",
    ]
    IAM = [
      "Policies",
      "Groups",
      "Users",
      "Instance profiles",
      "Server certificates",
      "Roles",
    ]
    Kinesis = [
      "Shards per region"
    ]
    RDS = [
      "Clusters",
      "Cluster parameter groups",
      "DB parameter groups",
      "DB instances",
      "Event subscriptions",
      "RDS DB Manual Snapshots",
      "Read replicas per master",
      "Storage quota (GB)",
      "Subnet groups",
      "Subnets per subnet group",
    ]
    Route53 = [
      "Route 53 Max Health Checks",
      "Route 53 Traffic Policy Instances",
      "Route 53 Hosted Zones",
      "Route 53 Reusable Delegation Sets",
      "Route 53 Traffic Policies",
    ]
    SES = [
      "Daily sending quota"
    ]
    VPC = [
      "EC2-VPC Elastic IP addresses (EIPs)",
      "Internet gateways",
      "VPCs",
    ]
  }

  service_limit_regions = flatten(
    [
      for service_name, limits in local.service_limits : [
        for service_limit in limits : [
          for region in var.regions : {
            alarm_name    = format("%s%s-%s-%s", var.alarm_name_prefix, region, service_name, replace(service_limit, "/[\\W_]+/", ""))
            region        = region
            service_name  = service_name
            service_limit = service_limit
          }
        ]
      ] if !contains(var.disabled_services, service_name)
    ]
  )

  resources = {
    for item in local.service_limit_regions : item.alarm_name => {
      region        = item.region
      service_name  = item.service_name
      service_limit = item.service_limit
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "main" {
  for_each            = var.enabled ? local.resources : {}
  alarm_actions       = var.cloudwatch_alarm_actions
  alarm_description   = "Service '${each.value.service_name}' quota '${each.value.service_limit}' usage too high in region '${each.value.region}'"
  alarm_name          = each.key
  comparison_operator = "GreaterThanThreshold"
  datapoints_to_alarm = 1
  evaluation_periods  = 1
  metric_name         = "ServiceLimitUsage"
  namespace           = "AWS/TrustedAdvisor"
  ok_actions          = var.cloudwatch_alarm_actions
  period              = 300
  statistic           = "Maximum"
  tags                = var.tags
  threshold           = var.cloudwatch_alarm_threshold / 100
  treat_missing_data  = "ignore"

  dimensions = {
    "Region"       = each.value["region"]
    "ServiceLimit" = each.value["service_limit"]
    "ServiceName"  = each.value["service_name"]
  }
}
