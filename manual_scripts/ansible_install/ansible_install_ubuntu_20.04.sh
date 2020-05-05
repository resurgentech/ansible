# install Ansible
apt update
apt install -y software-properties-common
# WORKAROUND - should be temporary, compare to 18.04 script
# Some repos are still using pre-release name eoan instead of focal for 20.04
#apt-add-repository --yes --update ppa:ansible/ansible
echo "deb http://ppa.launchpad.net/ansible/ansible/ubuntu eoan main" > /etc/apt/sources.list.d/ansible-ubuntu-ansible-focal.list
apt install -y ansible

# required for ansible over ssh connections
apt install -y sshpass
