locals {
  trusted_advisor_service_limits = {
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
    SES = [
      "Daily sending quota"
    ]
    VPC = [
      "EC2-VPC Elastic IP addresses (EIPs)",
      "Internet gateways",
      "VPCs",
    ]
  }

  usage_service_limits = {
    AutoScaling = {
      None = ["NumberOfAutoScalingGroup"]
    }
    CloudWatch = {
      None = ["InsightRule"]
    }
    DynamoDB = {
      None = [
        "AccountProvisionedWriteCapacityUnits",
        "AccountProvisionedReadCapacityUnits",
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
    SNS = {
      None = ["NumberOfMessagesPublishedPerAccount"]
    }
  }

  metrics_normalized_all = flatten([
    for region in var.regions : [
      for service_name, data in local.usage_service_limits : [
        for class, limits in data : [
          for resource in limits : {
            class        = class
            resource     = resource
            region       = region
            service_name = service_name
            id           = replace(replace(lower(replace(join("", [service_name, class, resource]), "-", "")), " ", ""), "/", "")
            label        = format("%s (%s): %s", service_name, class, resource)
          }
        ]
      ]
    ]
  ])

  metrics_normalized_service_region = {
    for service_name, data in local.usage_service_limits : service_name => {
      for region in var.regions : region => [for metric in local.metrics_normalized_all : metric if metric.region == region && metric.service_name == service_name]
    }
  }

  dashboard_widgets = flatten([
    for service_name, region_data in local.metrics_normalized_service_region : [
      for region, metrics in region_data : [
        {
          type = "metric"
          properties = {
            stat   = "Sum"
            region = region
            period = 300
            view   = "timeSeries"
            title  = format("%s: %s", service_name, region)
            yAxis = {
              left = {
                label     = "Quota usage percentage"
                max       = 100
                min       = 0
                showUnits = false
              }
            }
            metrics = concat([
              for metric in metrics : flatten([
                [
                  "AWS/Usage", "ResourceCount", "Class", metric["class"], "Resource", metric["resource"], "Service", metric["service_name"], "Type", "Resource",
                  { id = metric["id"], region = metric["region"], visible = false }
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

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "ServiceQuotaUsage"
  dashboard_body = jsonencode({ widgets = local.dashboard_widgets })
}
