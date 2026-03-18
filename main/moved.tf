moved {
  from = aws_instance.web
  to   = module.aws_ec2_1.aws_instance.web
}

moved {
  from = aws_db_subnet_group.cs1_db_subnets
  to   = module.aws_rds.aws_db_subnet_group.cs1_db_subnets
}

moved {
  from = aws_db_instance.cs1_db
  to   = module.aws_rds.aws_db_instance.cs1_db
}
