# install Ansible
apt update
apt install -y software-properties-common
apt install -y ansible

# required for ansible over ssh connections
apt install -y sshpass
