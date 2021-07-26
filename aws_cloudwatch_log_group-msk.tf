resource "aws_cloudwatch_log_group" "default" {
  count              = var.enabled ? 1 : 0
  name              = "/${local.solution_name_prefix}/${local.solution_context}/${var.cluster_instance}"
  retention_in_days = var.cloudwatch_logs_retention
}
