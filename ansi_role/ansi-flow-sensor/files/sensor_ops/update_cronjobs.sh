#!/usr/bin/bash
SERVICES_FILE=/home/ubuntu/data/services.txt
restart_L1=true
L1_freq="0 * * * *"
restart_L2=true
L2_freq="0 * * * *"
debug_freq="7 * * * *"

#######################################################################
source $SERVICES_FILE
crontab -l | grep 'sync_flow_sensor.sh' || echo "*/10 * * * * /home/ubuntu/sync_flow_sensor.sh" | crontab -
crontab -l | grep 'diagnosis.sh' || (crontab -l 2>/dev/null; echo "${debug_freq} /home/ubuntu/sensor_ops/diagnosis.sh") | crontab -
crontab -l | grep -E 'sync_flow_sensor.sh|diagnosis.sh' | crontab -

for service in ${services[@]}; do
  if [[ $service == F* ]] || [[ $service == f* ]]; then
    echo "Adding the crontab job for filebeat { $service }"
    if [[ $service == "f11_azure_nsg_flowlogs" ]]; then
      (crontab -l 2>/dev/null; echo "0 */4 * * * docker restart F11_azure_nsg_flowlogs") | crontab -
    elif [[ $service == "F9_perimeter81" ]] || [[ $service == "F13_cato" ]]; then
      (crontab -l 2>/dev/null; echo "0 */1 * * * docker restart $service") | crontab -
    elif [[ $service == "F22_splunk" ]] || [[ $service == "F23_qradar" ]] || [[ $service == "F25_sumologic" ]]; then
      (crontab -l 2>/dev/null; echo "0 0 * * * docker restart $service") | crontab -
    else
      (crontab -l 2>/dev/null; echo "*/10 * * * * docker restart $service") | crontab -
    fi
  elif [[ $service == "L1" ]] && [[ $restart_L1 == "true" ]]; then
   echo "Adding the crontab job for filebeat { $service }"
    (crontab -l 2>/dev/null; echo "${L1_freq} docker restart L1") | crontab -
  elif [[ $service == "L2" ]] && [[ $restart_L2 == "true" ]]; then
    echo "Adding the crontab job for filebeat { $service }"
    (crontab -l 2>/dev/null; echo "${L2_freq} docker restart L2") | crontab -
  fi
done
#######################################################################
