#!/usr/bin/bash

#Default values.
environment=""
location=""
username=`id -un`
home_dir="/home/"$username
install_base=$home_dir
push_metrics_user=''
push_metrics_pass=''
PUSHGATEWAY_SERVER=""
##############################

#reading configuration.
SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]:-$0}"; )" &> /dev/null && pwd 2> /dev/null; )";
CONFIG_FILE=$SCRIPT_DIR"/deployment.config"
source $CONFIG_FILE
##############################
define_services(){

[ -d $install_base"/logmon" ] || mkdir $install_base"/logmon"

## Creating the SystemD unit file for Prometheus
cat > $install_base/logmon/prometheus.service <<EOF
[Unit]
Description=Systemd unit file for Prometheus

[Service]
WorkingDirectory=$install_base
ExecStart=/usr/bin/prometheus --storage.tsdb.path="$install_base/data/prometheus/" --storage.tsdb.retention.time="3d" --config.file="$install_base/data/logmon/prometheus.yml" --web.listen-address="127.0.0.1:9090"
Restart=on-failure
RestartSec=5
User=prometheus
ExecReload=/bin/kill -HUP \$MAINPID
TimeoutStopSec=20s
SendSIGKILL=no

[Install]
WantedBy=multi-user.target
EOF
#add prometheus user to $username group for working directory access.
sudo usermod -aG $username prometheus
sudo mv $install_base/logmon/prometheus.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable prometheus --now
sudo systemctl restart prometheus

##Creating the Prometheus-Node-Exporter SystemD unit file.
cat > $install_base/logmon/node_exporter.service <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/node_exporter --collector.tcpstat --collector.systemd --collector.filesystem.ignored-mount-points=^/(sys|proc|dev|run)(\$|/)
[Install]
WantedBy=multi-user.target
EOF
sudo mv $install_base/logmon/node_exporter.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable node_exporter --now
sudo systemctl restart node_exporter

##Creating the Promtail SystemD unit file.
cat > $install_base/logmon/promtail.service <<EOF
[Unit]
Description=Promtail service
After=network.target

[Service]
Environment="INSTANCE=$tenant_info"
Type=simple
User=promtail
ExecStart=/usr/bin/promtail -config.file $install_base/data/logmon/promtail.yml -config.expand-env=true
# Give a reasonable amount of time for promtail to start up/shut down
TimeoutSec = 60
Restart = on-failure
RestartSec = 2

[Install]
WantedBy=multi-user.target
EOF
sudo adduser --system --no-create-home --group promtail || echo "add promtail user"
sudo usermod -aG $username promtail
sudo usermod -aG docker promtail
sudo mv -f $install_base/logmon/promtail.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable promtail --now
sudo systemctl restart promtail

  # #Configuring Cadvisor.
sudo cp -f $install_base/data/logmon/cadvisor_environment /etc/default/cadvisor
sudo cp -f $install_base/data/logmon/cadvisor.service /etc/systemd/system/cadvisor.service
sudo systemctl daemon-reload
sudo systemctl enable cadvisor --now
sudo systemctl restart cadvisor

##Creating the flow-sensor SystemD unit file.
cat > flow-sensor.service <<EOF
[Unit]
Description=Docker Compose Flow Sensor Service
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$install_base/data
EnvironmentFile=$install_base/data/services.txt
ExecStart=/usr/bin/bash -c '/usr/bin/docker-compose up -d \$services'
#ExecStart=/home/ubuntu/start_flowsensor.sh
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
sudo cp flow-sensor.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable flow-sensor --now

##Creating the update-fs-token command.
sudo mv /tmp/update-fs-token /usr/bin/update-fs-token
sudo chmod +x /usr/bin/update-fs-token
sudo chown ubuntu:ubuntu /usr/bin/update-fs-token

}

define_services