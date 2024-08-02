#!/bin/bash
ACCESS_KEY=/home/ubuntu/mountdir/am_config/access.tkn
RETRY_COUNT=5
need_diagnosis='no'
source /home/ubuntu/data/services.txt

if [[ $need_diagnosis == 'yes' ]]; then
  timestamp="$(TZ='Asia/Kolkata' date +%Y%m%d%H%M)"
  cd /home/ubuntu
  mkdir debug
  echo "=====================================" > debug/debug.log
  echo "running docker containers " >> debug/debug.log
  sudo docker ps >> debug/debug.log

  sudo docker ps --format '{{.Names}}' | awk '{print "\necho \"---------------"$1"-------------\" >> debug/debug.log 2>&1 \ndocker logs --tail 100 "$1 " >> debug/debug.log 2>&1"}' | bash
  echo "==================CRONTAB==================" >> debug/debug.log
  crontab -l -u ubuntu >> debug/debug.log

  sudo docker cp amservice:/opt/amservice/fs.log debug/fs.log
  sudo docker cp amservice:/opt/amservice/sc.log debug/sc.log
  sudo docker cp amservice:/opt/amservice/sc_error.log debug/sc_error.log || echo "get sc_error logs"
  sudo docker cp amservice:/opt/amservice/fs_error.log debug/fs_error.log || echo "get fs_error logs"

  cp /home/ubuntu/data/services.txt debug/service.txt

  [[ " ${services[*]} " =~ "L1" ]] && sudo timeout 30 tcpdump  -i any port 5044 -A -n -v  -U > debug/tcpdump_5044_AD_sensor
  [[ " ${services[*]} " =~ "F2" ]] && sudo timeout 30 tcpdump  -i any port 9044 -A -n -v  -U > debug/tcpdump_9044_net_flow
  [[ " ${services[*]} " =~ "F3" ]] && sudo timeout 30 tcpdump  -i any port 6343 -A -n -v  -U > debug/tcpdump_6343_sflow
  [[ " ${services[*]} " =~ "F4" ]] && sudo timeout 30 tcpdump  -i any port 9525 -A -n -v  -U > debug/tcpdump_9525_cisco_meraki_flow
  [[ " ${services[*]} " =~ "F5" ]] && sudo timeout 30 tcpdump  -i any port 9797 -A -n -v  -U > debug/tcpdump_9797_openvpn_flow
  [[ " ${services[*]} " =~ "F6" ]] && sudo timeout 30 tcpdump  -i any port 9004 -A -n -v  -U > debug/tcpdump_9004_fortinet_flow
  [[ " ${services[*]} " =~ "F7" ]] && sudo timeout 30 tcpdump  -i any port 9001 -A -n -v  -U > debug/tcpdump_9001_checkpoint_flow
  [[ " ${services[*]} " =~ "F8_f5vpn" ]] && sudo timeout 30 tcpdump  -i any port 9504 -A -n -v  -U > debug/tcpdump_9504_f5vpn_flow
  [[ " ${services[*]} " =~ "F10_bastionssh" ]] && sudo timeout 30 tcpdump  -i any port 9504 -A -n -v  -U > debug/tcpdump_9045_bastion_flow
  [[ " ${services[*]} " =~ "F13_cato" ]] && sudo timeout 30 tcpdump  -i any port 9021 -A -n -v  -U > debug/tcpdump_9021_cato_flow
  [[ " ${services[*]} " =~ "F14_zscaler_zia_web" ]] && sudo timeout 30 tcpdump  -i any port 9006 -A -n -v  -U > debug/tcpdump_9006_zip_web_flow
  [[ " ${services[*]} " =~ "F15_zscaler_zia_dns" ]] && sudo timeout 30 tcpdump  -i any port 9007 -A -n -v  -U > debug/tcpdump_9007_zia_dns_flow
  [[ " ${services[*]} " =~ "F16_zscaler_zpa_user_activity" ]] && sudo timeout 30 tcpdump  -i any port 9008 -A -n -v  -U > debug/tcpdump_9008__zpa_user_activity_flow
  [[ " ${services[*]} " =~ "F17_cisco_asa" ]] && sudo timeout 30 tcpdump  -i any port '(9012 or 9013)' -A -n -v  -U > debug/tcpdump_9012_9013_cisco_asa_flow
  [[ " ${services[*]} " =~ "F18_cisco_ftd" ]] && sudo timeout 30 tcpdump  -i any port '(9014 or 9017)' -A -n -v  -U > debug/tcpdump_9014_9017_cisco_ftd_flow
  [[ " ${services[*]} " =~ "F19_sonicwall" ]] && sudo timeout 30 tcpdump  -i any port 9015 -A -n -v  -U > debug/tcpdump_9015_sonicwall_flow
  [[ " ${services[*]} " =~ "F21_paloalto" ]] && sudo timeout 30 tcpdump  -i any port 9016 -A -n -v  -U > debug/tcpdump_9016_paloalto_flow

  ([[ " ${services[*]} " =~ "F22_splunk" ]] && sudo cp -r /home/ubuntu/data/F22_splunk/execution_logs debug/splunk_execution_log) || echo "collection splunk logs"
  tar cfz "data_$timestamp.tar.gz" "data"
  mv "data_$timestamp.tar.gz" debug
  mv debug "debug_$timestamp"
  tar cfz "debug_$TENANT_ID_$SENSOR_ID_$timestamp.tar.gz" "debug_$timestamp"

  EXEC=0
  while [[ $EXEC -lt $RETRY_COUNT ]];
  do
    am-data-xfer -u  $SENSOR_ID -e $BACKEND_URL -t $ACCESS_KEY -f debug_$TENANT_ID_$SENSOR_ID_$timestamp.tar.gz
    if [[ $? == 0 ]]; then
      EXEC=5
    else
      sleep 3
      EXEC=$(expr $EXEC + 1)
      if [[ $EXEC == $RETRY_COUNT ]]; then
        echo "Fail to upload diagnosis data to backend."
      fi
    fi
  done

  sudo rm -rf debug_*
fi

