#!/usr/bin/bash

#Default values.
environment=""
location=""
username=`id -un`
home_dir="/home/"$username
install_base=$home_dir

SLACK_CHANNEL=''
SLACK_URL=""
##############################

#reading configuration.
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
CONFIG_FILE=$SCRIPT_DIR"/deployment.config"
source $CONFIG_FILE
mv $SCRIPT_DIR"/deployment.config-bkp" $SCRIPT_DIR"/deployment.config"
##############################

sudo rm -rf $home_dir"/.aws"
sudo rm -rf

#Cleaning up /tmp dir
sudo rm -rf /tmp/deployment-scripts /tmp/sensor_ops /tmp/fix_installtion /tmp/*.sh /tmp/motd /tmp/sudoers

##Removing unwanted binaries
sudo apt -y remove ImageMagick*
sudo apt-get autoremove --purge -y
sudo apt-get clean
sudo apt-get autoclean