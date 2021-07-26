

data aws_vpc "selected" {
  id = "vpc-0e3ecdb6b39a04917"
}

data aws_subnet_ids "private" {
  vpc_id = data.aws_vpc.selected.id

  filter {
    name   = "tag:Scheme"
    values = ["private"]
  }
}

data aws_subnet "private" {
  for_each = data.aws_subnet_ids.private.ids
  id = each.value
}

