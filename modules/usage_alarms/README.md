## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.1.0 |
| <a name="provider_local"></a> [local](#provider\_local) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_metric_alarm.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [local_file.metrics](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alarm_name_prefix"></a> [alarm\_name\_prefix](#input\_alarm\_name\_prefix) | A string prefix for all cloudwatch alarms | `string` | `"ServiceQuota"` | no |
| <a name="input_cloudwatch_alarm_actions"></a> [cloudwatch\_alarm\_actions](#input\_cloudwatch\_alarm\_actions) | Actions for all cloudwatch alarms. e.g. an SNS topic ARN | `list(string)` | `[]` | no |
| <a name="input_cloudwatch_alarm_threshold"></a> [cloudwatch\_alarm\_threshold](#input\_cloudwatch\_alarm\_threshold) | The threshold for all cloudwatch alarms. This is a percentage of the limit so should be between 1-100 | `number` | `80` | no |
| <a name="input_disabled_services"></a> [disabled\_services](#input\_disabled\_services) | List of services to disable. See main.tf for list | `list(string)` | `[]` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | If set to false no cloudwatch alarms will be created | `bool` | `true` | no |
| <a name="input_metric_data_file"></a> [metric\_data\_file](#input\_metric\_data\_file) | Path to YAML file containing the metrics to create alarms for. By default the one contained in the module will be used. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to add to all cloudwatch alarms | `map(string)` | `{}` | no |

## Outputs

No outputs.
