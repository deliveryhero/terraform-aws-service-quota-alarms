locals {
  regions = [
    "ap-southeast-1",
    "eu-west-1",
    "us-east-1",
  ]
}

module "trusted_advisor_alarms" {
  source  = "../modules/trusted_advisor_alarms"
  regions = local.regions

  providers = {
    aws = aws.us-east-1
  }
}


module "usage_alarms_ap_southeast_1" {
  source = "../modules/usage_alarms"

  providers = {
    aws = aws.ap-southeast-1
  }
}

module "usage_alarms_eu_west_1" {
  source = "../modules/usage_alarms"

  providers = {
    aws = aws.eu-west-1
  }
}

module "usage_alarms_us_east_1" {
  source = "../modules/usage_alarms"

  providers = {
    aws = aws.us-east-1
  }
}
