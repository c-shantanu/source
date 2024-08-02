#!/usr/bin/bash

exec &> >(tee -i /home/ubuntu/sensor_ops/kickstart.log)
echo "Start time >> $(date -u +%Y-%m-%dT%H:%M:%SZ)"

sudo systemctl stop flow-sensor.service
sudo sh -c ":> /home/ubuntu/mountdir/am_config/proxy_creds.txt"
sudo sh -c ":> /home/ubuntu/mountdir/am_config/ssl.pem"
sudo chown root.root /home/ubuntu/mountdir/am_config/*
echo "starting flow-sensor.service"
sudo systemctl start flow-sensor.service

echo "wait for amservice to start"
sleep 30

cp /home/ubuntu/mountdir/am_config/proxy_creds.txt /home/ubuntu/sensor_ops/proxy_creds.txt
cp /home/ubuntu/mountdir/am_config/ssl.pem /home/ubuntu/sensor_ops/ssl.pem

echo "configuring proxy in system."
chmod +x /home/ubuntu/sensor_ops/configure_proxy.sh && /home/ubuntu/sensor_ops/configure_proxy.sh || echo "configure proxy env"

echo "run cloud cleanup script."
chmod +x /home/ubuntu/deployment-scripts/clean_cloud_driver.sh && /home/ubuntu/deployment-scripts/clean_cloud_driver.sh || echo "cloud cleanup"

echo "run sync_flow_sensor.sh"
chmod +x /home/ubuntu/sync_flow_sensor.sh && /home/ubuntu/sync_flow_sensor.sh || echo "sync flowsensor"

echo "configure the flowsensor post amervice is up and running"
chmod +x /home/ubuntu/sensor_ops/configure_system.sh && /home/ubuntu/sensor_ops/configure_system.sh || echo "configure system"

echo "configuring cronjobs."
chmod +x /home/ubuntu/sensor_ops/update_cronjobs.sh && /home/ubuntu/sensor_ops/update_cronjobs.sh || echo "configure cron"

echo "end time >> $(date -u +%Y-%m-%dT%H:%M:%SZ)"
