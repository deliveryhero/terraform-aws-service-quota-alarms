# terraform-aws-service-quota-alarms

The goal of this repository is to create a comprehensive AWS service quota monitoring solution with CloudWatch alarms for when a service quota limit is approached.

Included are 3 terraform modules:

- [modules/trusted_advisor_alarms](modules/trusted_advisor_alarms): Creates alarms for metrics in the `AWS/TrustedAdvisor` namespace for for quotas from multiple regions. This module should only be defined once in the `us-east-1` region.
- [modules/usage_alarms](modules/usage_alarms): Creates alarms for metrics in the `AWS/Usage` namespace. This module needs to be defined for each region that is to be monitored.
- [modules/dashboard](modules/dashboard): Creates a CloudWatch dashboard for all service quotas. This module should only be defined once in the `us-east-1` region.

## Example

See [example](example) for a full example implementation of all modules, multiple regions and multiple terraform AWS providers.

```hcl
module "dashboard" {
  source  = "git::https://github.com/deliveryhero/terraform-aws-service-quota-alarms.git//modules/dashboard?ref=1.9"
  regions = ["us-east-1"]
}

module "trusted_advisor_alarms" {
  source  = "git::https://github.com/deliveryhero/terraform-aws-service-quota-alarms.git//modules/trusted_advisor_alarms?ref=1.9"
  regions = ["us-east-1"]
}

module "usage_alarms" {
  source = "git::https://github.com/deliveryhero/terraform-aws-service-quota-alarms.git//modules/usage_alarms?ref=1.9"
}
```

## Details

The [get-supported-metrics](tools/get-supported-metrics) tool will get a current list of all supported quota metrics from the CloudWatch API by doing the following:
- Get all metrics from the `AWS/TrustedAdvisor` namespace, for each metric:
  - Filters for metric name `ServiceLimitUsage`
  - Tests if the metric contains an AWS region within the dimensions to determine if metric is for a global or regional quota
- Get all metrics from the `AWS/Usage` namespace, for each metric:
  - Filters by testing support for the `SERVICE_QUOTA` math function by calling the `GetMetricData` API

After filtering all metrics from both namespaces, the results are written to the [supported-metrics.yaml](modules/usage_alarms/supported-metrics.yaml) file. This file used within each terraform module to create the CloudWatch alarms and dashboard.

## Challenges of measuring AWS service quota usage

The goal initially sounded simple but has proved to be anything but due to the following challenges:

1. Many AWS services do not have service quota usage metrics available, for example SQS
2. Some service quota usage metrics have bugs, for example `ClassicLoadBalancersPerRegion` usage is measured against the default limit as opposed to the actual limit (AWS support case `13461384751`)
3. Service quota usage metrics are split across 2 CloudWatch namespaces, each with their own challenges and differences:
   - `AWS/TrustedAdvisor`
     - Not many service quotas are supported
     - Alarms can only be created in the `us-east-1` region but have a metric dimension to specify the region of the service quota
   - `AWS/Usage`:
      - To calculate actual usage of a quota, the metric must support the `SERVICE_QUOTA` math function, but:
        - Many service quotas metrics do not support the function
        - There is no documented list of metrics that support the function and AWS will not provide one (AWS support case `172297011100665`)
        - So each metric must be tested via a CloudWatch `GetMetricData` API call to see if supports the function
      - The statistic used to correctly calculate quota usage is inconsistent, requires trial and error. For example, the `SNS/NumberOfMessagesPublishedPerAccount` metric needs `Sum` statistic but most other metrics need `Maximum`
      - Alarms have to be created in each region
4. There is overlap in some service quotas between the two above namespaces, for example:
   - "NetworkLoadBalancersPerRegion" under `AWS/Usage`
   - "Active Network Load Balancers" under `AWS/TrustedAdvisor`
5. Usage metrics are only available for AWS services that are actually used, so
   - Each account and region requires a unique set of alarms
   - A unified list of metrics cannot be used because alarms will fail to create when the metric is not present
   - If a per account and region curated list of metrics is created, it needs to be updated if usage for a new AWS service is started

Interestingly, AWS published their own "reference implementation" for a quota monitoring [here](https://github.com/aws-solutions/quota-monitor-for-aws) but the complexity is staggering:

- 6 Lambda functions
- 3 DynamoDB tables
- Various event bus and triggers
- Resources need to be created in "hub" and "spoke" accounts

## Further reading

- https://docs.aws.amazon.com/awssupport/latest/user/cloudwatch-metrics-ta.html
- https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Quotas-Visualize-Alarms.html
- https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Usage-Metrics.html
