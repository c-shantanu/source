#!/usr/bin/bash

BACKEND_DETAILS="/home/ubuntu/mountdir/am_config/proxy_creds.txt"
CRT_FILE="/home/ubuntu/mountdir/am_config/ssl.pem"
#######################################################################
REFRESH_TKN=$(awk -F= '/refresh_token=/{print $2;}' $BACKEND_DETAILS | tail -1)
SENSOR_ID=$(awk -F= '/sensor_id=/{print $2;}' $BACKEND_DETAILS | tail -1)
TENANT_ID=$(awk -F= '/tenant_id=/{print $2;}' $BACKEND_DETAILS | tail -1)
BACKEND_URL=$(echo $REFRESH_TKN | jq -RrM 'split(".") | .[1] | @base64d | fromjson | .url')
PROXY_URL=$(awk -F= '/proxy_url=/{print $2;}' $BACKEND_DETAILS | tail -1)
PROXY_URL=$(echo $PROXY_URL | sed -E 's/^\s*.*:\/\///g')
PROXY_USER=$(awk -F= '/proxy_username=/{print $2;}' $BACKEND_DETAILS | tail -1)
PROXY_PASS=$(awk -F= '/proxy_password=/{print $2;}' $BACKEND_DETAILS | tail -1)
PROXY=""
if [[ $PROXY_URL != "" ]]; then
PROXY=""
  if [[ $PROXY_USER != "" ]]; then
    PROXY="${PROXY_USER}:${PROXY_PASS}@"
  fi
  PROXY="${PROXY}${PROXY_URL}"
fi

if [[ $(wc -l < $CRT_FILE) -gt 1 ]]; then
  sudo mkdir /usr/local/share/ca-certificates || echo "ensure ca-certificates directory exist."
  sudo cp $CRT_FILE /usr/local/share/ca-certificates/proxy.crt
  sudo update-ca-certificates
  echo "Install SSL certificate in system at /usr/local/share/ca-certificates/proxy.crt."
fi

if [[ $PROXY != "" ]]; then #need to configure the proxy.

#configure proxy in /etc/environments
  (grep -q http_proxy /etc/environment && sudo sed -i "/http_proxy/chttp_proxy=$PROXY" /etc/environment) || (echo "http_proxy=$PROXY" |sudo tee -a /etc/environment > /dev/null)
  (grep -q HTTP_PROXY /etc/environment && sudo sed -i "/HTTP_PROXY/cHTTP_PROXY=$PROXY" /etc/environment) || (echo "HTTP_PROXY=$PROXY" |sudo tee -a /etc/environment > /dev/null)
  (grep -q https_proxy /etc/environment && sudo sed -i "/https_proxy/chttps_proxy=$PROXY" /etc/environment) || (echo "https_proxy=$PROXY" |sudo tee -a /etc/environment > /dev/null)
  (grep -q HTTPS_PROXY /etc/environment && sudo sed -i "/HTTPS_PROXY/cHTTPS_PROXY=$PROXY" /etc/environment) || (echo "HTTPS_PROXY=$PROXY" |sudo tee -a /etc/environment > /dev/null)
  (grep -q ftp_proxy /etc/environment && sudo sed -i "/ftp_proxy/cftp_proxy=$PROXY" /etc/environment) || (echo "ftp_proxy=$PROXY" |sudo tee -a /etc/environment > /dev/null)
  (grep -q FTP_PROXY /etc/environment && sudo sed -i "/FTP_PROXY/cFTP_PROXY=$PROXY" /etc/environment) || (echo "FTP_PROXY=$PROXY" |sudo tee -a /etc/environment > /dev/null)
  (grep -q no_proxy /etc/environment && sudo sed -i "/no_proxy/cno_proxy=localhost,127.0.0.1,::1" /etc/environment) || (echo "no_proxy=localhost,127.0.0.1,::1" |sudo tee -a /etc/environment > /dev/null)
  (grep -q NO_PROXY /etc/environment && sudo sed -i "/NO_PROXY/cNO_PROXY=localhost,127.0.0.1,::1" /etc/environment) || (echo "NO_PROXY=localhost,127.0.0.1,::1" |sudo tee -a /etc/environment > /dev/null)
  echo "configured PROXY in /etc/environments."

#configure proxy in docker service.
  echo -e "{\n  \"proxies\": {\n    \"http-proxy\": \"${PROXY}\",\n    \"https-proxy\": \"${PROXY}\",\n    \"no-proxy\": \"localhost,127.0.0.1,::1\"\n  }\n}" > proxy.json
  jq -s add /etc/docker/daemon.json proxy.json > docker.proxy.json
  sudo mv docker.proxy.json /etc/docker/daemon.json
  sudo systemctl daemon-reload
  sudo systemctl restart docker
  echo "configured proxy in docker at /etc/docker/daemon.json."

#configure proxy in APT
  echo -e "Acquire {\n  http::proxy \"${PROXY}\";\n  https::proxy  \"${PROXY}\";\n  ftp::proxy  \"${PROXY}\";\n}" | sudo tee /etc/apt/apt.conf.d/proxy.conf
  echo "configured proxy in APT at /etc/apt/apt.conf.d/proxy.conf."
fi

#######################################################################
#configure system environment variables.
echo "configured PROXY in /etc/environments."
(grep -q TENANT_ID /etc/environment && sudo sed -i "/TENANT_ID/cTENANT_ID=$TENANT_ID" /etc/environment) || (echo "TENANT_ID=$TENANT_ID" |sudo tee -a /etc/environment > /dev/null)
(grep -q SENSOR_ID /etc/environment && sudo sed -i "/SENSOR_ID/cSENSOR_ID=$SENSOR_ID" /etc/environment) || (echo "SENSOR_ID=$SENSOR_ID" |sudo tee -a /etc/environment > /dev/null)
(grep -q BACKEND_URL /etc/environment && sudo sed -i "/BACKEND_URL/cBACKEND_URL=$BACKEND_URL" /etc/environment) || (echo "BACKEND_URL=$BACKEND_URL" |sudo tee -a /etc/environment > /dev/null)
