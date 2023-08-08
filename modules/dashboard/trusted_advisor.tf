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

  trusted_advisor_metrics_normalized_all = flatten([
    for region in var.regions : [
      for service_name, limits in local.trusted_advisor_service_limits : [
        for resource in limits : {
          resource     = resource
          region       = region
          service_name = service_name
          id           = lower(replace(format("%s%s", service_name, resource), "/[\\W_]+/", ""))
          label        = format("%s: %s", service_name, resource)
        }
      ]
    ]
  ])

  trusted_advisor_metrics_normalized_service_region = {
    for service_name, limits in local.trusted_advisor_service_limits : service_name => {
      for region in var.regions : region => [for metric in local.trusted_advisor_metrics_normalized_all : metric if metric.region == region && metric.service_name == service_name]
    }
  }

  trusted_advisor_dashboard_widgets = flatten([
    for service_name, region_data in local.trusted_advisor_metrics_normalized_service_region : [
      for region, metrics in region_data : [
        {
          type = "metric"
          properties = {
            stat   = "Sum"
            region = "us-east-1"
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
                  "AWS/TrustedAdvisor", "ServiceLimitUsage", "ServiceName", metric["service_name"], "ServiceLimit", metric["resource"], "Region", metric["region"],
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
