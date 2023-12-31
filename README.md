# terraform-aws-service-quota-alarms

The modules in this repo will create CloudWatch alarms for all available, critical AWS service quotas limits. Included are 3 terraform modules:

- [modules/trusted_advisor_alarms](modules/trusted_advisor_alarms): Creates alarms in the `AWS/TrustedAdvisor` namespace for for quotas from multiple regions. This module should only be defined once in the `us-east-1` region.
- [modules/usage_alarms](modules/usage_alarms): Creates alarms in the `AWS/Usage` namespace. This module needs to be defined for each region that is to be monitored.
- [modules/dashboard](modules/dashboard): Creates a CloudWatch dashboard for all service quotas. This module should only be defined once in the `us-east-1` region.

## Example

See [example](example) for a full example implimentation of both modules, multiple regions and multiple terraform AWS providers.

```hcl
module "dashboard" {
  source  = "git::https://github.com/deliveryhero/terraform-aws-service-quota-alarms.git//modules/dashboard?ref=1.6"
  regions = ["us-east-1"]
}

module "trusted_advisor_alarms" {
  source  = "git::https://github.com/deliveryhero/terraform-aws-service-quota-alarms.git//modules/trusted_advisor_alarms?ref=1.6"
  regions = ["us-east-1"]
}

module "usage_alarms" {
  source = "git::https://github.com/deliveryhero/terraform-aws-service-quota-alarms.git//modules/usage_alarms?ref=1.6"
}
```

## Details

AWS service quotas can be monitored in 2 different CloudWatch namespaces:

* 1\. `AWS/TrustedAdvisor`: These metrics come from the [Trusted Advisor](https://aws.amazon.com/premiumsupport/technology/trusted-advisor/) service and are simply represent usage of the specific quota limit as a percentage. These metrics are availble for all regions but are only visible in the `us-east-1` region.
* 2\. `AWS/Usage`: There are many metrics in this namespace that are split by 3 different `metric_name`:
  * a) `CallCount`: Most of the metrics in this namespace are of this type and are about rate limits of specific API calls for each service
  * b) `ResourceCount`: These metrics are mostly about the count of certain resource types per service
  * c) `ThrottleCount`: A few specific throttling metrics only for the CloudWatch service

The modules will create alarms for all metrics from items 1 and 2b.

It will not create alarms for items:

- 2a: These metrics do not support the `SERVICE_QUOTA` math function so an alarm threshold cannot be set
- 2c: These do not look critical or useful

### Challenges of measuring service quota usage

Generally the implementation in AWS for measuring service quota usage seems inconsistent. The metrics are split across 2 different CloudWatch namespaces, each measured in a different way. There is many services in the `AWS/Usage` CloudWatch namespace that do not support the `SERVICE_QUOTA` math function so measurement of usage against the current quota limit is not possible. Some AWS services have metrics in both namespaces, e.g. `EC2`. And some metrics under 2b are not a count of resource, e.g. `SNS/NumberOfMessagesPublishedPerAccount` which measures messages published per second. Furthermore, there seems to be a bug with `Elastic Load Balancing/*` quotas where the quota usage is always measured against the default limit, not the actual limit. And there exists additional inconsistencies in the AWS Service Quota console where the utilization numbers do not match the provided CloudWatch dashboard panel, for example with `SNS/NumberOfMessagesPublishedPerAccount`.

## Further reading

- https://docs.aws.amazon.com/awssupport/latest/user/cloudwatch-metrics-ta.html
- https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Quotas-Visualize-Alarms.html
- https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Usage-Metrics.html
