module "kafka_default"{
  source = "../"

  name                  = "bubble_tea"
  vpc_id                = data.aws_vpc.selected.id
  private_subnet_ids    = data.aws_subnet_ids.private.ids
  enabled                = true
  kafka_version          = "2.6.0"
  number_of_broker_nodes = 3
  broker_instance_type   = "kafka.m5.large"
  client_sasl_scram_enabled = true
  cloudwatch_logs_enabled =  true
  port_list = ["2181","9096"]
  allowed_cidr_blocks = {
    "9096" = ["0.0.0.0/0"]
  }
  security_groups = ["sg-0909021b21dbac609"]
  properties = {
    "auto.create.topics.enable" = true
    "default.replication.factor" = 3
    "min.insync.replicas" = 2
    "num.io.threads" = 8
    "num.network.threads" = 5
    "num.partitions" = 3
    "num.replica.fetchers" = 2
    "replica.lag.time.max.ms" = 30000
    "socket.receive.buffer.bytes" = 102400
    "socket.request.max.bytes" = 104857600
    "socket.send.buffer.bytes" = 102400
    "unclean.leader.election.enable" = true
    "zookeeper.session.timeout.ms" = 18000
  }
}