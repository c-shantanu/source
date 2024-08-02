#!/usr/bin/bash
ACCESS_KEY=/home/ubuntu/mountdir/am_config/access.tkn
REGISTRY_CREDS=/home/ubuntu/sensor_ops/registry_creds.txt
SERVICES_FILE=/home/ubuntu/data/services.txt
RETRY_COUNT=5
#Get docker registry creds.
source /etc/environment
CONTAINER_REGISTRY=$BACKEND_URL
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

#GET Docker registry credentials.
touch $REGISTRY_CREDS
EXEC=0
while [[ $EXEC -lt $RETRY_COUNT ]];
do
  am-data-xfer -d $SENSOR_ID -e $BACKEND_URL -t $ACCESS_KEY  -f $REGISTRY_CREDS
  if [[ $? == 0 ]]; then
    EXEC=5
  else
    sleep 3
	EXEC=$(expr $EXEC + 1)
	if [[ $EXEC == $RETRY_COUNT ]]; then
	  echo "Fail to get registry credentials. retry timeout."
	fi
  fi
done

#######################################################################
#start flowsensor conatiners
if [[ $(wc -l < $REGISTRY_CREDS) -gt 0 ]]; then
  /usr/bin/docker login -u $(head -1 $REGISTRY_CREDS) -p $(tail -1 $REGISTRY_CREDS) $CONTAINER_REGISTRY
  source $SERVICES_FILE
  if [[ ${services[*]} =~ 'cntlm' ]]; then
    base_services=(cntlm redis amservice)
  else
    base_services=(redis amservice)
  fi
  if [[ ${services[*]} =~ 'L1' ]]; then
    base_services=(${base_services[@]} L1 L2)
  else
    base_services=(${base_services[@]} L2)
  fi
  for delete in ${base_services[@]}; do services=( "${services[@]/$delete}" ); done
  s_services=(${base_services[@]} ${services[@]})
  for service in ${s_services[@]}; do
      if [ $service  == "cntlm" ]; then
          echo "startign cntlm"
          /usr/bin/docker-compose up -d $service
          sleep 5
      elif [ $service  == "amservice" ]; then
          echo "starting amservice"
          /usr/bin/docker-compose up -d $service
          sleep 15
      elif [ $service == "L1" ] || [ $service == "L2" ]; then
          echo "starting $service"
          /usr/bin/docker-compose up -d $service
          sleep 20
      elif [ $service == "f11_azure_nsg_flowlogs" ]; then
          echo "starting $service"
          sleep 5
          /usr/bin/docker-compose up -d $service
          sleep 20
      else
          echo "Starting $service"
          /usr/bin/docker-compose up -d $service
      fi
  done
  /usr/bin/docker logout $CONTAINER_REGISTRY
else
  echo "Fail to get registry credentials."
  send_slack_alert "failed to get docker registry credentials." "failure"
  exit 1
fi
#######################################################################
