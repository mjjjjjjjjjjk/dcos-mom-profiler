#!/bin/bash

# Determine your DC/OS cluster's public node's ip address
# Defaults to 'core' for CoreOS systems.   
# Optionally supply an alternate user account name, e.g. 'centos' for CentOS based clusters.

CURRENT_DIRECTORY=""

if [ $# -ne 0 ]; then
	USER_ID="--user=$1"
else
	USER_ID="--user=core"
fi

PUBLIC_AGENTS=$(dcos node --json | jq --raw-output '.[] | select(.attributes.public_ip == "true") | .id')

for id in ${PUBLIC_AGENTS[@]}; do
	echo "Mesos ID: $id"
	IP=$( dcos node ssh --option StrictHostKeyChecking=no  --option LogLevel=quiet --master-proxy --user=core --mesos-id=$id "curl ifconfig.co/json" ) 
        # This is your public node;
        echo ""
        echo ""
	echo $IP | jq .
done
