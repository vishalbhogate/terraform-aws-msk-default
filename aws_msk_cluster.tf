locals {
  bootstrap_brokers               = try(aws_msk_cluster.default[0].bootstrap_brokers, "")
  bootstrap_brokers_list          = local.bootstrap_brokers != "" ? sort(split(",", local.bootstrap_brokers)) : []
  bootstrap_brokers_tls           = try(aws_msk_cluster.default[0].bootstrap_brokers_tls, "")
  bootstrap_brokers_tls_list      = local.bootstrap_brokers_tls != "" ? sort(split(",", local.bootstrap_brokers_tls)) : []
  bootstrap_brokers_scram         = try(aws_msk_cluster.default[0].bootstrap_brokers_sasl_scram, "")
  bootstrap_brokers_scram_list    = local.bootstrap_brokers_scram != "" ? sort(split(",", local.bootstrap_brokers_scram)) : []
  bootstrap_brokers_combined_list = concat(local.bootstrap_brokers_list, local.bootstrap_brokers_tls_list, local.bootstrap_brokers_scram_list)
}

resource "aws_msk_cluster" "default" {
  count                  = var.enabled ? 1 : 0
  cluster_name           = local.cluster_name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.number_of_broker_nodes
  enhanced_monitoring    = var.enhanced_monitoring

  broker_node_group_info {
    instance_type   = var.broker_instance_type
    ebs_volume_size = var.broker_volume_size
    client_subnets  = data.aws_subnet_ids.private.ids
    security_groups = aws_security_group.default.*.id
  }

  configuration_info {
    arn      = aws_msk_configuration.config[0].arn
    revision = aws_msk_configuration.config[0].latest_revision
  }

  encryption_info {
    encryption_in_transit {
      client_broker = var.client_broker
      in_cluster    = var.encryption_in_cluster
    }
    encryption_at_rest_kms_key_arn = aws_kms_key.kms[0].arn
  }

  dynamic "client_authentication" {
    for_each = var.client_tls_auth_enabled || var.client_sasl_scram_enabled ? [1] : []
    content {
      dynamic "tls" {
        for_each = var.client_tls_auth_enabled ? [1] : []
        content {
          certificate_authority_arns = var.certificate_authority_arns
        }
      }
      dynamic "sasl" {
        for_each = var.client_sasl_scram_enabled ? [1] : []
        content {
          scram = var.client_sasl_scram_enabled
        }
      }
    }
  }

  open_monitoring {
    prometheus {
      jmx_exporter {
        enabled_in_broker = var.jmx_exporter_enabled
      }
      node_exporter {
        enabled_in_broker = var.node_exporter_enabled
      }
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = var.cloudwatch_logs_enabled
        log_group = aws_cloudwatch_log_group.default[0].name
      }
      firehose {
        enabled         = var.firehose_logs_enabled
        delivery_stream = var.firehose_delivery_stream
      }
      s3 {
        enabled = var.s3_logs_enabled
        bucket  = var.s3_logs_bucket
        prefix  = var.s3_logs_prefix
      }
    }
  }

  tags = merge({
    "Name" = local.cluster_name
    },
    local.tags
  )
}

resource "aws_ssm_parameter" "kafka_arn" {
  count                  = var.enabled ? 1 : 0
  name        = "/app/${local.solution_name_prefix}/${local.solution_context}/${var.cluster_instance}/MSK_ARN"
  description = "MSK ARN"
  type        = "String"
  value       = aws_msk_cluster.default[0].arn
}

resource "aws_ssm_parameter" "bootstrap_brokers" {
  count                  = var.enabled ? 1 : 0
  name        = "/app/${local.solution_name_prefix}/${local.solution_context}/${var.cluster_instance}/BOOTSTRAP_BROKERS"
  description = "MSK Bootstrap Brokers"
  type        = "String"
  value       = var.client_tls_auth_enabled ? aws_msk_cluster.default[0].bootstrap_brokers_tls : var.client_sasl_scram_enabled ? aws_msk_cluster.default[0].bootstrap_brokers_sasl_scram : aws_msk_cluster.default[0].bootstrap_brokers
}

resource "aws_ssm_parameter" "zookeeper_connect_string" {
  count                  = var.enabled ? 1 : 0
  name        = "/app/${local.solution_name_prefix}/${local.solution_context}/${var.cluster_instance}/ZOOKEEPER_CONNECT_STRING"
  description = "MSK Zookeeper Connect String"
  type        = "String"
  value       = aws_msk_cluster.default[0].zookeeper_connect_string
}

resource "aws_appautoscaling_target" "kafka_storage" {
  count              = var.enabled ? 1 : 0
  max_capacity       = var.scaling_max_capacity
  min_capacity       = 1
  resource_id        = aws_msk_cluster.default[count.index].arn
  scalable_dimension = "kafka:broker-storage:VolumeSize"
  service_namespace  = "kafka"
}

resource "aws_appautoscaling_policy" "kafka_broker_scaling_policy" {
  count              = var.enabled ? 1 : 0
  name               = "${local.cluster_name}-broker-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_msk_cluster.default[count.index].arn
  scalable_dimension = aws_appautoscaling_target.kafka_storage[count.index].scalable_dimension
  service_namespace  = aws_appautoscaling_target.kafka_storage[count.index].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "KafkaBrokerStorageUtilization"
    }

    target_value = var.scaling_target_value
  }
}