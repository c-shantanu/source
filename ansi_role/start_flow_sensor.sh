#!/usr/bin/bash

#Default values.
environment=""
location=""
username=`id -un`
home_dir="/home/"$username
install_base=$home_dir

SLACK_CHANNEL=''
SLACK_URL=""

DOCKER_USER=""
DOCKER_PASS=""
CONTAINER_REGISTRY="console.authmind.com"
##############################

#reading configuration.
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
CONFIG_FILE=$SCRIPT_DIR"/deployment.config"
source $CONFIG_FILE
##############################


#get_s3_object <s3 object url> <destinaion file with path>
get_s3_object(){
  aws s3 cp $1 $2
  if [[ $(echo $?) != "0" ]]; then
    echo "Failed to download $1! Error Exiting..."
    exit 1
  fi
}

source $home_dir/.aws/credentials
get_s3_object s3://$S3_BUCKET/$environment/$location/sha256.txt sha256.txt
get_s3_object s3://$S3_BUCKET/$environment/$location/$environment.zip $environment.zip

sha256sum $environment.zip > sha256.txt.current
diff sha256.txt sha256.txt.current
if [[ $(echo $?) == "0" ]]; then
  rm -rf $environment $install_base/data
  unzip $environment.zip -d $install_base/data
  
  mkdir -p $install_base/mountdir/am_config/  ||  echo "verify mountdir/am_config/ directory exist."
    #put updated amservice configuration file.
  sudo cp -f $install_base/data/amservice_build/config.ini $install_base/mountdir/am_config/config.ini
  sudo cp -f $install_base/data/amservice_build/keyring_pass.cfg $install_base/mountdir/am_config/keyring_pass.cfg
  sudo cp -f $install_base/data/amservice_build/keyringrc.cfg $install_base/mountdir/am_config/keyringrc.cfg
  chmod 775 $install_base/mountdir/am_config/ &&  sudo chown root:root $install_base/mountdir/am_config/*
  sudo chown root:root $install_base/data/F12_cisco_umbrella/modules.d/cisco.yml
  sudo chown root:root $install_base/data/F*/filebeat.yml
  echo "downgrading the docker-compose version from 3.9 to 3.3"
  sed -i '1s/3.9/3.3/g' $install_base/data/docker-compose.yml
  cp $install_base/data/ease_of_deployment/sync_flow_sensor.sh $install_base/ && chmod +x $install_base/sync_flow_sensor.sh

  cd $install_base/data
  source services.txt
  docker login -u $DOCKER_USER  -p $DOCKER_PASS $CONTAINER_REGISTRY
  docker-compose up -d $services
  docker logout $CONTAINER_REGISTRY
  curl -X POST --data-urlencode "payload={\"channel\": \"$SLACK_CHANNEL\", \"username\": \"flow-sensor-bot-$environment\", \"text\": \"Flow-sensor Deployed for { $environment } in location { $location } with services { $services }.\", \"icon_emoji\": \":dart:\"}" $SLACK_URL
else
    echo ">>>>>>>>>>>>> ERROR <<<<<<<<<<<<<"
    echo "Checksum failed for s3://$S3_BUCKET/$environment/$location/$environment.zip ..."
    echo "Please rerun the deployment script."
	echo "--------------------------------"
    exit 1
fi

