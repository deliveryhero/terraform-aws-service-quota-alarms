## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.1.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.1.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_metric_alarm.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alarm_name_prefix"></a> [alarm\_name\_prefix](#input\_alarm\_name\_prefix) | n/a | `string` | `"service-quotas-"` | no |
| <a name="input_cloudwatch_alarm_actions"></a> [cloudwatch\_alarm\_actions](#input\_cloudwatch\_alarm\_actions) | n/a | `list(string)` | `[]` | no |
| <a name="input_cloudwatch_alarm_threshold"></a> [cloudwatch\_alarm\_threshold](#input\_cloudwatch\_alarm\_threshold) | n/a | `number` | `80` | no |
| <a name="input_disabled_services"></a> [disabled\_services](#input\_disabled\_services) | List of services to disable | `list(string)` | `[]` | no |
| <a name="input_enabled"></a> [enabled](#input\_enabled) | n/a | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | n/a | `map(string)` | `{}` | no |

## Outputs

No outputs.
