#!/bin/bash

directory=/home/ubuntu/data/ease_of_deployment/sensor_ops/binaries

echo "Checking for new binaries..."
cd /tmp

if [ -d "$directory" ]; then
    files=$(ls -A "$directory")
    if [ -n "$files" ]; then
        echo "New binaries found."
        for file in "$directory"/*; do
            base_file_name=$(basename "$file")
            file_name=$(basename "$base_file_name" | cut -d. -f1)
            sudo mv $file /tmp/$base_file_name

            if [[ "$file" == *"cadvisor"* ]]; then
                sudo mv -f $file_name /usr/bin/cadvisor
                sudo systemctl restart cadvisor
            elif [[ "$file" == *"crowdstrike"* ]]; then
                sudo dpkg -i ./$base_file_name
                sudo mv -f ./$base_file_name /home/ubuntu/installers
            elif [[ "$file" == *"node_exporter"* ]]; then
                sudo tar -xvf $base_file_name
                sudo mv -f $file_name/node_exporter /usr/bin/
                sudo systemctl restart node_exporter
            elif [[ "$file" == *"prometheus"* ]]; then
                sudo tar -xvf $base_file_name
                sudo mv -f $file_name/prometheus /usr/bin/
                sudo mv -f $file_name/promtool /usr/bin/
                sudo systemctl restart prometheus
            elif [[ "$file" == *"promtail"* ]]; then
                sudo unzip $base_file_name
                sudo mv -f $file_name /usr/bin/promtail
                sudo systemctl restart promtail
            elif [[ "$file" == *"am-data-xfer"* ]]; then
                sudo mv -f $file_name /usr/bin/am-data-xfer
                sudo chmod +x /usr/bin/am-data-xfer
            else
                echo "No match found."
            fi
        done
    fi
else
    echo "No new binaries found."
fi