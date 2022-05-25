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

# Remote users #

Both as the first step on a new remote machine (not a workstation with a normal local monitor) and the first step as a new admin for existing machines is to make sure your user is set up.  These steps are also used to update a users password.

### Set/change password, sudo, and ssh keys for admin users
This will set up password-less ssh and sudo on the machines in the inventory file.
```
./scripts/setup_user.sh inventory-production.ini
```
You have to pass in the inventory file to the script.

First, this will prompt for `new password for USER=user:` which is your user password.

Then, it prompt for `SSH password:` which is the root password on the remote system.

### Set/change vnc passwords
To enable your vnc session set the vnc password after the users are set up.
```
./scripts/set_vnc_password.sh inventory-production.ini
```
You should run the `setup_user.sh` script first.

#### NOTE: Enabling vnc in this way for a user blocks a local console from logging on.  Only use if you know what you're doing.

### Change root (or user) password
Root and admin users other than your local user are special cases, they don't enable all the the same stuff and they can't infer the user from the shell on your workstation so you have to add it as a second parameter.
```
./scripts/setup_user.sh inventory-production.ini root
```
Only changes the password for root.

```
./scripts/setup_user.sh inventory-production.ini user
```
Changes password and configures sudo access like a normal admin user but does not prompt for ssh keys

# Configure Remote Machines #

```
ansible-playbook -i inventory-production.ini playbook-vmhost.yml
```
If your user was successfully configured, you can run this one, shot as your user, no prompts.

If something goes haywire you can try adding `-k` to prompt for your user, `-K` for your users SUDO password.  If you user is really screwy you can run it as root with `-u root` and `-k`.
