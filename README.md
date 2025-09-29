
terraform init -upgrade
terraform plan -var-file=terraform.tfvars
terraform apply -auto-approve -var-file=terraform.tfvars
terraform destroy -auto-approve -var-file=terraform.tfvars

ssh -i "~/Documents/aws/key_pair_01.pem" \
     -N \
     -R 3000:localhost:3000 \
     -R 5432:localhost:5432 \
     -c chacha20-poly1305@openssh.com \
     -o "ServerAliveInterval=60" \
     -o "ServerAliveCountMax=3" \
     -o "ControlMaster=auto" \
     -o "ControlPath=~/.ssh/control-%r@%h:%p" \
     ubuntu@13.218.108.84

ssh -i "~/Documents/aws/key_pair_01.pem" \
     -N \
     -R 3000:localhost:3000 \
     -R 5432:localhost:5432 \
     -c aes128-gcm@openssh.com \
     -o "ServerAliveInterval=60" \
     -o "ServerAliveCountMax=3" \
     -o "ControlMaster=auto" \
     -o "ControlPath=~/.ssh/control-%r@%h:%p" \
     ubuntu@13.218.108.84

ssh -R 5432:localhost:5432 -i "~/Documents/aws/key_pair_01.pem" ubuntu@13.218.206.118