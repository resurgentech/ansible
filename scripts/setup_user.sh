#!/bin/bash

# Operate at the base 
DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd ${DIR}/..

if [ -z $1 ]; then
  echo "inventory file required"
  exit 1
fi

if [ -z $2 ]; then
  MY_USER=$USER
else
  MY_USER=$2
fi

# hack to change root password
if [ "${2}" == "root" ]; then
  echo "setting root password, skipping other changes"
  MY_USER=$2
fi

read -p "new password for USER=$MY_USER: " -s MY_PASSWORD;
echo "";
ansible-playbook -i $1 playbook-setup_user.yml -k -K --extra-vars "my_user=$MY_USER my_password=$MY_PASSWORD";
unset MY_PASSWORD
