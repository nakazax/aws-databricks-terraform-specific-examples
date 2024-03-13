output "vpc_id" {
  value = aws_vpc.main_vpc.id
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private_subnets : s.id]
}

output "security_group_ids" {
  value = [aws_security_group.test_sg.id]
}

output "root_storage_bucket_name" {
  value = aws_s3_bucket.root_storage_bucket.bucket
}

output "cross_account_role_arn" {
  value = aws_iam_role.cross_account_role.arn
}
