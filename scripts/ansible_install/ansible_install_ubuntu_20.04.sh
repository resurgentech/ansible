# install Ansible
apt update
apt install -y software-properties-common
# WORKAROUND - should be temporary, compare to 18.04 script, install default.
#apt-add-repository --yes --update ppa:ansible/ansible
apt install -y ansible

# required for ansible over ssh connections
apt install -y sshpass
