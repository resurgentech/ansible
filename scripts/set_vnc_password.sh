#!/bin/bash

# Operate at the base 
DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd ${DIR}/..

if [ -z $1 ]; then
  echo "inventory file required"
  exit 1
fi

read -p "new VNC password for USER=$USER: " -s MY_PASSWORD;
echo "";
ansible -u $USER --become-user $USER -i $1 -m shell -a "printf \"${MY_PASSWORD}\n${MY_PASSWORD}\n\n\" | vncpasswd" all
unset MY_PASSWORD
