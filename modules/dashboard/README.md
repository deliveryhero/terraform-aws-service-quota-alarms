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
| [aws_cloudwatch_dashboard.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_dashboard) | resource |
| [local_file.metrics](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_disabled_services"></a> [disabled\_services](#input\_disabled\_services) | List of services to disable | `list(string)` | `[]` | no |
| <a name="input_metric_data_file"></a> [metric\_data\_file](#input\_metric\_data\_file) | Path to YAML file containing the metrics to create alarms for. By default the one contained in the module will be used. | `string` | `null` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | A list of AWS regions to create dashboard panels for | `list(string)` | `[]` | no |

## Outputs

No outputs.
