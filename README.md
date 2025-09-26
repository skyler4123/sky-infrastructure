terraform plan -var-file=terraform.tfvars
terraform apply -auto-approve -var-file=terraform.tfvars
terraform destroy -auto-approve -var-file=terraform.tfvars
