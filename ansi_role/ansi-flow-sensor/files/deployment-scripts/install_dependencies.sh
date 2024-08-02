#!/usr/bin/bash

#Default values.
username=`id -un`
aws_access_key_id=''
aws_secret_access_key=''
home_dir="/home/"$username
##############################

#reading configuration.
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
CONFIG_FILE=$SCRIPT_DIR"/deployment.config"
source $CONFIG_FILE
docker_storage='/mnt/docker'
##############################

echo "Reading -> "$SCRIPT_DIR"/deployment.config"

#function definations.
wait_apt() {
  while sudo fuser /var/lib/dpkg/lock* /var/lib/apt/lists/lock /var/cache/apt/archives/lock >/dev/null 2>&1;
  do echo 'Waiting for release of dpkg/apt locks';
    sleep 5;
  done;
}

install_dependencies() {
  sudo apt install apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  wait_apt && sudo DEBIAN_FRONTEND=noninteractive apt -y update
  wait_apt && sudo DEBIAN_FRONTEND=noninteractive apt -y upgrade
  wait_apt && sudo DEBIAN_FRONTEND=noninteractive apt -y install \
                                                         awscli \
                                                         docker-ce \
                                                         docker-compose \
                                                         dos2unix \
                                                         jq \
                                                         net-tools \
                                                         tree \
                                                         zip \
                                                         apt-file \
                                                         apt-offline \
                                                         tcpdump \
                                                         sysdig \
                                                         sysstat \
                                                         strace \
                                                         auditd \
                                                         emacs \
                                                         vim \
                                                         nmap \
                                                         netcat \
                                                         ethtool \
                                                         gdb \
                                                         lsof \
                                                         psmisc \
                                                         bpfcc-tools \
                                                         iotop \
                                                         iotop \
                                                         ltrace \
                                                         iproute2 \
                                                         bmon \
                                                         ncdu \
                                                         htop \
                                                         trace-cmd \
                                                         iperf \
                                                         iptraf-ng \
                                                         mtr \
                                                         procps \
                                                         dnstop \
                                                         util-linux \
                                                         linux-tools-generic
  wait_apt && sudo DEBIAN_FRONTEND=noninteractive apt-mark hold docker-ce

  #Docker configurations
  sudo systemctl stop docker.service
  sudo systemctl stop docker.socket
  sudo systemctl disable docker.service
  sudo systemctl disable docker.socket
  sudo mv /tmp/daemon.json /etc/docker/daemon.json
  sudo mv /var/lib/docker $docker_storage
  sudo mkdir -p $docker_storage
  sudo rm -rf /var/lib/docker
  sudo systemctl start docker.service
  sudo systemctl start docker.socket
  sudo systemctl enable docker.service
  sudo systemctl enable docker.socket

  #allow rw access to /var/run/docker.sock for user $username
  sudo chmod o+rw /var/run/docker.sock
  sudo usermod -aG docker $username
}

configuration_aws_creds(){
  echo "creating .aws directory"
  sudo [ -d $home_dir"/.aws" ] || sudo mkdir $home_dir"/.aws"
  sudo chown -R $username.$username $home_dir"/.aws"
  echo "creating .aws/credentials file"
  #echo -e "[default]\naws_access_key_id=$aws_access_key_id\naws_secret_access_key=$aws_secret_access_key" | sudo dd of=$home_dir"/.aws/credentials"
  echo -e "[default]\naws_access_key_id=$aws_access_key_id\naws_secret_access_key=$aws_secret_access_key" > $home_dir"/.aws/credentials"
  sudo chown -R $username"."$username $home_dir"/.aws"
}

install_dependencies
configuration_aws_creds
$SCRIPT_DIR"/install_binaries.sh"
