locals {
  name   = var.name
  region = var.region

  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  tags = {
    Organization  = "OpsFleet"
    Team          = "Infrastructure"
    Environment   = "Development"
  }
}