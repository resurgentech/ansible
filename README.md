# Basic Ansible Configurations for Desktop and Workstations

## Using to configure a fresh machine ##

### Installing ansible locally ###

Run the appropriate script from ./scripts/ansible_install/ with sudo

Example:
```bash
sudo ./scripts/ansible_install/ansible_install_ubuntu_20.04.sh
```

This allows you to use ansible locally to configure the machine as opposed to registering it with a remote ansible instance like Tower.

### Install ansible galaxy modules ###
This step will install the required 3rd party modules.
```bash
ansible-galaxy install -r requirements.yml --force
```
 The --force is optional, it will update your local copies to the latest if older versions present.  FYI - code ends up in ~/.ansible.

### Run ansible to configure machine ###

```bash
./setup_localhost.sh
```

Will prompt for BECOME password, in this context, this is current user's password required to run sudo.

# Table of Contents #

### group_vars/ ###
Global variables for this repo.

### scripts/ ###
Contains scripts for things that are best done run manually.

### roles/ ###
This directory is where all the magic happens.  Contains the various 'plays' for ansible to do the installations of various tools and such.

### ansible.cfg ###
Config file for ansible.

### playbook-dev_desktop.yml ###
Ansible 'playbook' for development desktop machine.

### inventory-localhost.yml ###
Inventory file for installing on localhost.

### setup_localhost.sh ###
Helper for installing.

* * *
