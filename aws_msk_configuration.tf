resource "aws_msk_configuration" "config" {
  count          = var.enabled ? 1 : 0
  kafka_versions = [var.kafka_version]
  name           = join("-", [local.solution_name_prefix, local.solution_context, "config"])
  description    = "Manages an Amazon Managed Streaming for Kafka configuration"
  server_properties = join("\n", [for k in keys(var.properties) : format("%s = %s", k, var.properties[k])])
}