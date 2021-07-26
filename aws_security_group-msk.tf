resource "aws_security_group" "default" {
  count       = var.enabled ? 1 : 0
  vpc_id      = data.aws_vpc.selected.id
  name        = join("-", [local.cluster_name, "sg"])
  description = "Inbound & Outbound Traffic MSK"
  tags = merge({
    "Name" = join("-", [local.cluster_name, "sg"])
    },
    local.tags
  )
}

resource "aws_security_group_rule" "ingress_security_groups" {
  count                    = var.enabled ? length(var.security_groups) : 0
  description              = "Allow inbound traffic from Security Groups"
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = var.security_groups[count.index]
  security_group_id        = join("", aws_security_group.default.*.id)
}

 resource "aws_security_group_rule" "ingress_cidr_blocks" {
    for_each    = var.enabled && var.allowed_cidr_blocks != "" ? var.allowed_cidr_blocks : {}
    description = "Allow inbound traffic from port ${each.key}"
    type        = "ingress"
    from_port   = each.key
    to_port     = each.key
    cidr_blocks = each.value
    protocol    = "tcp"
    security_group_id = join("", aws_security_group.default.*.id)
}

/* resource "aws_security_group_rule" "ingress_cidr_blocks" {
  count             = var.enabled && length(var.allowed_cidr_blocks) > 0 ? 1 : 0
  description       = "Allow inbound traffic from Private CIDR blocks"
  type              = "ingress"
  from_port         = var.client_tls_auth_enabled ? 9094 : var.client_sasl_scram_enabled ? 9096 : 9092
  to_port           = var.client_tls_auth_enabled ? 9094 : var.client_sasl_scram_enabled ? 9096 : 9092
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks
  security_group_id = join("", aws_security_group.default.*.id)
}
 */
resource "aws_security_group_rule" "ingress_private_cidr_blocks" {
  count             = var.enabled && length(var.port_list) > 0 ? length(var.port_list) : 0
  description       = "Allow inbound traffic from Private CIDR blocks"
  type              = "ingress"
  from_port         = var.port_list[count.index]
  to_port           = var.port_list[count.index]
  protocol          = "tcp"
  cidr_blocks       = values(data.aws_subnet.private).*.cidr_block
  security_group_id = join("", aws_security_group.default.*.id)
}

resource "aws_security_group_rule" "egress" {
  count             = var.enabled ? 1 : 0
  description       = "Allow all egress traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = join("", aws_security_group.default.*.id)
}