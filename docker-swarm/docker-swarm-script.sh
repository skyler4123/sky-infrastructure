
# Install Docker
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo groupadd --force docker
sudo usermod -aG docker $USER
newgrp docker
docker run hello-world

docker swarm init --autolock --cert-expiry 8760h0m0s --advertise-addr 52.207.224.117
docker swarm init --autolock --cert-expiry 8760h0m0s --advertise-addr 10.0.43.151


# Swarm initialized: current node (ke4rouvr3yz7wc97id18avyzz) is now a manager.

# To add a worker to this swarm, run the following command:

#     docker swarm join --token SWMTKN-1-3dv6qxtkrzhk1yomwl7gbxm9acpvzwqwfppz1rh26zkc6laai5-2no3colhxf4kevc6o4xu3qza2 54.87.63.186:2377

# To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.
# To unlock a swarm manager after it restarts, run the `docker swarm unlock`
# command and provide the following key:

#     SWMKEY-1-etrGzoLScb9G+fxCUmD44xtkCQ2yapcCZm48cehygqg

# Remember to store this key in a password manager, since without it you

docker node update --label-add node_rule=postgresql_master <node_id>
docker node update --label-add node_rule=postgresql_slave_1 <node_id>
docker stack deploy -c postgres-stack.yml postgres-stack