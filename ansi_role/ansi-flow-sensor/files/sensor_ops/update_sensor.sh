#!/bin/bash
directory=/home/ubuntu
#######################################################################
#. docker system cleanup
docker_cleanup(){
  test "$(docker ps -q | wc -l)" -gt "0" && docker stop $(docker ps -q)  || echo 'ensure all containers are in stop state'
  test "$(docker ps -aq | wc -l)" -gt "0" && docker rm $(docker ps -aq)  || echo 'remove all containers'
  #remove docker images which no longer required
  required_images=`grep 'image:' $directory/data/docker-compose.yml | awk '{ print $2}' | tr -d '"' | tr '\n' '|'`
  required_images=${required_images::-1}
  docker system prune -f
  docker images --format "table {{.ID}}\t{{.Repository}}:{{.Tag}}" | grep -vE $required_images | grep -v 'IMAGE ID' | awk '{print "docker image rmi -f " $1}' | bash 2>&1 /dev/null | echo "remove images no longer required"
  docker system prune -f
}
#######################################################################
source /etc/environment

echo "creating the systemd unit file for flow-sensor"
/home/ubuntu/sensor_ops/enable_sensor_service.sh

echo "stopping all the flow-sensor containers"
sudo systemctl stop flow-sensor.service

mkdir -p $directory/backup
mkdir -p $directory/mountdir/am_config/  ||  echo "verify mountdir/am_config/ directory exist."
chmod 775 $directory/mountdir/am_config/

#backup lookup_files
echo "backup lookup_files"
if [[ -d $directory/data/lookup_files ]]; then
  cp -rf $directory/data/lookup_files $directory/backup
fi

echo "deleting the old flow-sensor configurations"
sudo rm -rf $directory/data
mkdir -p $directory/data

cd $directory/data
echo "uncompressing the new flow-sensor configuration"
mv $directory/${TENANT_ID}_${SENSOR_ID}_config.tar.gz $directory/data && tar zxf ${TENANT_ID}_${SENSOR_ID}_config.tar.gz

echo "Updating the sync mechanism itself"
sudo chown -R ubuntu.ubuntu  $directory/sensor_ops
cp $directory/sync_flow_sensor.sh $directory/sync_flow_sensor.sh.backup || echo "backup"
cp $directory/data/ease_of_deployment/sync_flow_sensor.sh $directory/sync_flow_sensor.sh
cp $directory/sensor_ops/configure_proxy.sh $directory/sensor_ops/configure_proxy.sh.backup  || echo "backup"
cp $directory/data/ease_of_deployment/sensor_ops/configure_proxy.sh $directory/sensor_ops/configure_proxy.sh
cp $directory/sensor_ops/configure_system.sh $directory/sensor_ops/configure_system.sh.backup  || echo "backup"
cp $directory/data/ease_of_deployment/sensor_ops/configure_system.sh $directory/sensor_ops/configure_system.sh
cp $directory/sensor_ops/enable_sensor_service.sh $directory/sensor_ops/enable_sensor_service.sh.backup  || echo "backup"
cp $directory/data/ease_of_deployment/sensor_ops/enable_sensor_service.sh $directory/sensor_ops/enable_sensor_service.sh
cp $directory/sensor_ops/start_sensor.sh $directory/sensor_ops/start_sensor.sh.backup  || echo "backup"
cp $directory/data/ease_of_deployment/sensor_ops/start_sensor.sh $directory/sensor_ops/start_sensor.sh
cp $directory/sensor_ops/update_cronjobs.sh $directory/sensor_ops/update_cronjobs.sh.backup || echo "backup"
cp $directory/data/ease_of_deployment/sensor_ops/update_cronjobs.sh $directory/sensor_ops/update_cronjobs.sh
cp $directory/sensor_ops/update_sensor.sh $directory/sensor_ops/update_sensor.sh.backup || echo "backup"
cp $directory/data/ease_of_deployment/sensor_ops/update_sensor.sh $directory/sensor_ops/update_sensor.sh
cp $directory/sensor_ops/diagnosis.sh $directory/sensor_ops/diagnosis.sh.backup || echo "backup"
cp $directory/data/ease_of_deployment/sensor_ops/diagnosis.sh $directory/sensor_ops/diagnosis.sh
cp $directory/data/monitoring/diagnosis.sh $directory/monitoring/diagnosis.sh
cp $directory/sensor_ops/upgrade_binaries.sh $directory/sensor_ops/upgrade_binaries.sh.backup || echo "backup"
cp $directory/data/ease_of_deployment/sensor_ops/upgrade_binaries.sh $directory/sensor_ops/upgrade_binaries.sh
chmod +x $directory/sensor_ops/*.sh $directory/monitoring/diagnosis.sh
sudo chown root:root $directory/data/F12_cisco_umbrella/modules.d/cisco.yml
sudo chown root:root $directory/data/F*/filebeat.yml
sudo chown -R ubuntu.ubuntu  $directory/sensor_ops
echo "downgrading the docker-compose version from 3.9 to 3.3"
sed -i '1s/3.9/3.3/g' $directory/data/docker-compose.yml
chmod +x $directory/monitoring/*.sh

##Upgrading binaries
sh $directory/sensor_ops/upgrade_binaries.sh

#put updated amservice configuration file.
sudo cp -f $directory/data/amservice_build/config.ini $directory/mountdir/am_config/config.ini
sudo cp -f $directory/data/amservice_build/keyring_pass.cfg $directory/mountdir/am_config/keyring_pass.cfg
sudo cp -f $directory/data/amservice_build/keyringrc.cfg $directory/mountdir/am_config/keyringrc.cfg

test -f $directory/mountdir/am_config/refresh.tkn_baseline || ( test -f $directory/data/amservice_build/refresh.tkn && sudo cp $directory/data/amservice_build/refresh.tkn $directory/mountdir/am_config/refresh.tkn_baseline )
test -f $directory/mountdir/am_config/refresh.tkn || ( test -f $directory/data/amservice_build/refresh.tkn && sudo cp $directory/data/amservice_build/refresh.tkn $directory/mountdir/am_config/refresh.tkn )

if [[ -f $directory/data/amservice_build/refresh.tkn ]]; then
  sudo cp -f $directory/data/amservice_build/refresh.tkn $directory/mountdir/am_config/refresh.tkn
  sudo cp -f $directory/data/amservice_build/refresh.tkn $directory/mountdir/am_config/refresh.tkn_baseline
else
  #refresh.tkn file absent in flowsensor build
  sudo cp -f $directory/mountdir/am_config/refresh.tkn_baseline $directory/mountdir/am_config/refresh.tkn
fi


#change ownership of amservice configuration file.
sudo chown root:root $directory/mountdir/am_config/*

#restoring lookup files backup.
LOOKUP_FILES_2_UPDATE='dest_port_to_dest_type.json|dest_port_to_src_type.json|port_to_protocol.json|port_to_protocol_type.json|ports.json'
echo "restoring lookup_files backup"
if [[ -d $directory/backup/lookup_files ]]; then
  ls -1 $directory/backup/lookup_files/* | grep -vE $LOOKUP_FILES_2_UPDATE |awk '{ print "cp -f " $1 " " dir"/data/lookup_files/"}' dir="$directory" | bash
  #ls -1 $directory/backup/lookup_files/* | awk '{ print "cp -f " $1 " " dir"/data/lookup_files/"}' dir="$directory" | bash
fi

#create redis data directory if does not exist.
test -d $directory/redis_data || mkdir $directory/redis_data
sudo chown -R root:root $directory/redis_data

#perform docker system cleanup
#docker_cleanup

echo "starting all the flow-sensor containers"
sudo systemctl start flow-sensor.service

if [[ $(echo $?) == "0" ]]; then
  echo "Flow-sensor sync with S3 went successful!"
else
  echo "Flow-sensor sync with S3 went UN-successful, exiting..."
  exit 1
fi
