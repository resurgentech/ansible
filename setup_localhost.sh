ansible-playbook -u=$USER --connection=local \
-e 'ansible_python_interpreter=/usr/bin/python3' \
-i inventory.localhost.yml dev_desktop.yml -K $@
