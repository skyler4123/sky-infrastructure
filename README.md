
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
     -R 80:localhost:80 \
     -R 443:localhost:443 \
     -R 3000:localhost:3000 \
     -R 5432:localhost:5432 \
     -c aes128-gcm@openssh.com \
     -o "ServerAliveInterval=60" \
     -o "ServerAliveCountMax=3" \
     -o "ControlMaster=auto" \
     -o "ControlPath=~/.ssh/control-%r@%h:%p" \
     ubuntu@13.222.200.116

ssh -N \
     -R 80:localhost:80 \
     -R 443:localhost:443 \
     -R 5432:localhost:5432 \
     -c aes128-gcm@openssh.com \
     -o "ServerAliveInterval=60" \
     -o "ServerAliveCountMax=3" \
     -o "ControlMaster=auto" \
     -o "ControlPath=~/.ssh/control-%r@%h:%p" \
     root@138.68.1.92

ssh root@159.223.39.6
ssh -i "~/Documents/aws/key_pair_01.pem" ubuntu@54.224.255.124