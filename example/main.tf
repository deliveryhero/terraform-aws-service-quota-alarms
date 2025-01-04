locals {
  regions = [
    "ap-southeast-1",
    "eu-west-1",
    "us-east-1",
  ]
}

resource "aws_sns_topic" "this" {
  name = "alarms_topic"
}

module "dashboard" {
  source  = "../modules/dashboard"
  regions = local.regions

  providers = {
    aws = aws.us-east-1
  }
}

module "trusted_advisor_alarms" {
  source                   = "../modules/trusted_advisor_alarms"
  regions                  = local.regions
  cloudwatch_alarm_actions = [aws_sns_topic.this.arn]

  providers = {
    aws = aws.us-east-1
  }
}

module "usage_alarms_ap_southeast_1" {
  source                   = "../modules/usage_alarms"
  cloudwatch_alarm_actions = [aws_sns_topic.this.arn]

  providers = {
    aws = aws.ap-southeast-1
  }
}

module "usage_alarms_eu_west_1" {
  source                   = "../modules/usage_alarms"
  cloudwatch_alarm_actions = [aws_sns_topic.this.arn]

  providers = {
    aws = aws.eu-west-1
  }
}

module "usage_alarms_us_east_1" {
  source                   = "../modules/usage_alarms"
  cloudwatch_alarm_actions = [aws_sns_topic.this.arn]

  providers = {
    aws = aws.us-east-1
  }
}
