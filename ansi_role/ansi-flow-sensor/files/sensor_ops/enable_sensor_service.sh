#!/bin/bash

#######################################################################
cat > flow-sensor.service <<'EOF'
[Unit]
Description=Docker Compose Flow Sensor Service
Requires=docker.service
After=docker.service
[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ubuntu/data
EnvironmentFile=/home/ubuntu/data/services.txt
#ExecStart=/usr/bin/bash -c '/usr/bin/docker-compose up -d \$services'
ExecStart=/home/ubuntu/sensor_ops/start_sensor.sh
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0
[Install]
WantedBy=multi-user.target
EOF

sudo cp flow-sensor.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable flow-sensor.service
#######################################################################
