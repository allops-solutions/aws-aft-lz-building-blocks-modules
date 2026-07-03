resource "aws_securityhub_finding_aggregator" "this" {
  count = var.configuration_type == "CENTRAL" ? 1 : 0

  linking_mode      = var.linking_mode
  specified_regions = var.specified_regions
}

resource "aws_securityhub_organization_configuration" "this" {
  depends_on = [aws_securityhub_finding_aggregator.this]

  auto_enable           = var.auto_enable_accounts
  auto_enable_standards = var.auto_enable_standards ? "DEFAULT" : "NONE"

  organization_configuration {
    configuration_type = var.configuration_type
  }
}
