resource "aws_securityhub_configuration_policy" "policy" {
  name        = var.name
  description = var.description

  configuration_policy {
    service_enabled       = var.service_enabled
    enabled_standard_arns = var.enabled_standard_arns

    security_controls_configuration {
      disabled_control_identifiers = var.disabled_control_identifiers
      enabled_control_identifiers  = var.enabled_control_identifiers

      dynamic "security_control_custom_parameter" {
        for_each = { for i in var.security_control_custom_parameter : i.security_control_id => i.parameters }
        content {
          security_control_id = security_control_custom_parameter.key

          dynamic "parameter" {
            for_each = { for p in security_control_custom_parameter.value : p.name => p }
            content {
              name       = parameter.key
              value_type = parameter.value.value_type

              dynamic "bool" {
                for_each = try(parameter.value["bool"], null) != null ? { value = parameter.value["bool"] } : {}
                content {
                  value = bool.value
                }
              }
              dynamic "double" {
                for_each = try(parameter.value["double"], null) != null ? { value = parameter.value["double"] } : {}
                content {
                  value = double.value
                }
              }
              dynamic "enum" {
                for_each = try(parameter.value["enum"], null) != null ? { value = parameter.value["enum"] } : {}
                content {
                  value = enum.value
                }
              }
              dynamic "enum_list" {
                for_each = try(parameter.value["enum_list"], null) != null ? { value = parameter.value["enum_list"] } : {}
                content {
                  value = enum_list.value
                }
              }
              dynamic "int" {
                for_each = try(parameter.value["int"], null) != null ? { value = parameter.value["int"] } : {}
                content {
                  value = int.value
                }
              }
              dynamic "int_list" {
                for_each = try(parameter.value["int_list"], null) != null ? { value = parameter.value["int_list"] } : {}
                content {
                  value = int_list.value
                }
              }
              dynamic "string" {
                for_each = try(parameter.value["string"], null) != null ? { value = parameter.value["string"] } : {}
                content {
                  value = string.value
                }
              }
              dynamic "string_list" {
                for_each = try(parameter.value["string_list"], null) != null ? { value = parameter.value["string_list"] } : {}
                content {
                  value = string_list.value
                }
              }
            }
          }
        }
      }
    }
  }
}

resource "aws_securityhub_configuration_policy_association" "association" {
  for_each   = toset(var.association_targets)
  depends_on = [aws_securityhub_configuration_policy.policy]

  target_id = each.value
  policy_id = aws_securityhub_configuration_policy.policy.id
}
