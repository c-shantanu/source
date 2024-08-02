#!/usr/bin/bash

exec &> >(tee -i /home/ubuntu/sensor_ops/invoke_kickstart.log)
echo "Start time >> $(date -u +%Y-%m-%dT%H:%M:%SZ)"

mkdir -p /home/ubuntu/mountdir/am_config || echo "ensure amservice config directory exist"
chmod +x /home/ubuntu/deployment-scripts/kickstart.sh && /home/ubuntu/deployment-scripts/kickstart.sh

echo -e "\n====================================\n======= proxy_creds.txt ============\n"
cat /home/ubuntu/mountdir/am_config/proxy_creds.txt
echo -e "\n====================================\n"

echo -e "\n====================================\n============ ssl.epm ===============\n"
cat /home/ubuntu/mountdir/am_config/ssl.pem
echo -e "\n=================================== =\n"

/home/ubuntu/sync_flow_sensor.sh
echo "Configuration setup completed!"

echo "end time >> $(date -u +%Y-%m-%dT%H:%M:%SZ)"
