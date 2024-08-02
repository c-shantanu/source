#!/usr/bin/bash

#Default values.
prometheus_version="2.45.4"
node_exporter_version="1.7.0"
promtail_version="2.9.6"
cadvisor_version="0.49.1"

install_binaries(){
  #install non python binary for downloading s3 objects
  sudo curl 'https://dl.min.io/client/mc/release/linux-amd64/mc' -o /usr/local/bin/mc
  sudo chmod +x /usr/local/bin/mc
  #/usr/local/bin/mc -q alias set s3 https://s3.amazonaws.com $aws_access_key_id $aws_secret_access_key

  #installing the prometheus
  echo "installing prometheus"
  cd /tmp
  curl -LO https://github.com/prometheus/prometheus/releases/download/v$prometheus_version/prometheus-$prometheus_version.linux-amd64.tar.gz
  tar -xvf prometheus-$prometheus_version.linux-amd64.tar.gz
  sudo mv prometheus-$prometheus_version.linux-amd64/prometheus /usr/bin/
  sudo mv prometheus-$prometheus_version.linux-amd64/promtool /usr/bin/
  sudo useradd prometheus
  sudo mkdir /data && sudo chown prometheus /data
  rm -rf /tmp/prometheus-$prometheus_version.linux-amd64*

  #installing node exporter.
  echo "installing node-exporter"
  cd /tmp
  curl -LO https://github.com/prometheus/node_exporter/releases/download/v$node_exporter_version/node_exporter-$node_exporter_version.linux-amd64.tar.gz
  tar -xvf node_exporter-$node_exporter_version.linux-amd64.tar.gz
  sudo mv node_exporter-$node_exporter_version.linux-amd64/node_exporter /usr/bin/
  rm -rf /tmp/node_exporter-$node_exporter_version.linux-amd64*

  #installing promtail
  echo "installing promtail"
  cd /tmp
  curl -LO https://github.com/grafana/loki/releases/download/v$promtail_version/promtail-linux-amd64.zip
  unzip promtail-linux-amd64.zip
  sudo mv promtail-linux-amd64 /usr/bin/promtail
  rm -rf /tmp/promtail-linux-amd64*

  #installing cadvisor
  echo "installing cadvisor"
  cd /tmp
  curl -LO https://github.com/google/cadvisor/releases/download/v$cadvisor_version/cadvisor-v$cadvisor_version-linux-amd64
  sudo mv cadvisor-v$cadvisor_version-linux-amd64 /usr/bin/cadvisor
  sudo chmod +x /usr/bin/cadvisor

  #install am-data-xfer
  source ~/.aws/credentials
  aws s3 cp s3://ambuilds/flow-sensor-installers/am-data-xfer .
  sudo mv ./am-data-xfer /usr/bin/
  sudo chmod +x /usr/bin/am-data-xfer
}

install_packages() {
  #install crowdstrike-cs-falconhoseclient_2.18.0_amd64.deb
  source ~/.aws/credentials
  aws s3 cp s3://ambuilds/flow-sensor-installers/crowdstrike-cs-falconhoseclient_2.18.0_amd64.deb .
  sudo dpkg -i ./crowdstrike-cs-falconhoseclient_2.18.0_amd64.deb
  sudo systemctl disable cs.falconhoseclientd.service
  mkdir /home/ubuntu/installers || echo "creating installer directory"
  mv ./crowdstrike-cs-falconhoseclient_2.18.0_amd64.deb /home/ubuntu/installers
}

install_binaries
install_packages