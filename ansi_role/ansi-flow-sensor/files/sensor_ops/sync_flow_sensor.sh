#!/bin/bash
#######################################################################
RETRY_COUNT=5
#Get docker registry creds.
source /etc/environment
SHA_DIR=/home/ubuntu/sensor_ops
directory=/home/ubuntu
ACCESS_KEY=/home/ubuntu/mountdir/am_config/access.tkn
SLACK_CHANNEL="test-alerts"
#######################################################################
send_slack_alert(){
  sender=${TENANT_ID:0:16}--${SENSOR_ID}
  success_icon=':white_check_mark:'
  failure_icon=':x:'
  message=$1
  result=${2:-default} #success|failure|default
  if [[ $result == "failure" ]]; then
    icon=':x:'
  elif [[ $result == "success" ]]; then
    icon=':white_check_mark:'
  else
    icon=':ballot_box_with_check:'
  fi
  am-data-xfer -k $SENSOR_ID -e $BACKEND_URL -t $ACCESS_KEY -n $SLACK_CHANNEL -r $sender -m "$message" -i $icon 
}

#GET config sha256 sum.
get_config_sha(){
  EXEC=0
  while [[ $EXEC -lt $RETRY_COUNT ]];
  do
    am-data-xfer -s $SENSOR_ID -e $BACKEND_URL -t $ACCESS_KEY  -f $SHA_DIR/sha256.txt
    if [[ $? == 0 ]]; then
      EXEC=5
    else
      sleep 3
      EXEC=$(expr $EXEC + 1)
  	  if [[ $EXEC == $RETRY_COUNT ]]; then
  	    echo "Fail to get config sha256 sum. retry timeout."
        send_slack_alert "failed to download configuration hash" "failure"
        exit
      fi
    fi
  done
}

get_config() {
  EXEC=0
  while [[ $EXEC -lt $RETRY_COUNT ]];
  do
    am-data-xfer -c $SENSOR_ID -e $BACKEND_URL -t $ACCESS_KEY  -f $directory/${TENANT_ID}_${SENSOR_ID}_config.tar.gz
    if [[ $? == 0 ]]; then
      EXEC=5
    else
      sleep 3
      EXEC=$(expr $EXEC + 1)
  	  if [[ $EXEC == $RETRY_COUNT ]]; then
  	    echo "Fail to get flowsensor config updates. retry timeout."
        send_slack_alert "failed to download configuration update" "failure"
        exit 1
      fi
    fi
  done
}


if [[ ! -f $SHA_DIR/sha256.txt ]]; then
  touch $SHA_DIR/sha256.txt
fi

mv -f $SHA_DIR/sha256.txt $SHA_DIR/sha256.txt.old
get_config_sha
diff $SHA_DIR/sha256.txt $SHA_DIR/sha256.txt.old
if [[ $(echo $?) == "0" ]]; then
  echo "there is no update for the { $environment } flow sensor...exiting"
  exit 0
else
  send_slack_alert "detected configuration update"
  get_config
  cd $directory; sha256sum ${TENANT_ID}_${SENSOR_ID}_config.tar.gz > $SHA_DIR/sha256.txt.current; cd -
  diff $SHA_DIR/sha256.txt $SHA_DIR/sha256.txt.current
  if [[ $(echo $?) == "0" ]]; then
    echo "the downloaded checksum matched with the downloaded file"
    send_slack_alert "download configuration update"
  else
    echo "the downloaded checksum failed to match with the downloaded file"
    send_slack_alert "failed to download configuration update" "failure"
	exit 1
  fi
  $directory/sensor_ops/update_sensor.sh
  $directory/sensor_ops/update_cronjobs.sh
  PROXY_CREDS_RES=$(diff /home/ubuntu/mountdir/am_config/proxy_creds.txt /home/ubuntu/sensor_ops/proxy_creds.txt)
  SSL_RES=$(diff /home/ubuntu/mountdir/am_config/ssl.pem /home/ubuntu/sensor_ops/ssl.pem)
  if [[ $PROXY_CREDS_RES != 0 ]] || [[ $SSL_RES != 0 ]]; then
    $directory/sensor_ops/configure_proxy.sh
  fi
  $directory/sensor_ops/configure_system.sh
  send_slack_alert "successfully updated the flowsensor" "success"
fi

#######################################################################
