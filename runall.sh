#!/bin/bash


set -x

dcos package install marathon-lb
dcos package install marathon
dcos marathon app add ./profbox7.JSON


dcos marathon app show /marathon-user > ./marathon-user.JSON
./add_jmx_config_to_mom_json.sh ./marathon-user.JSON

dcos marathon app add ./marathon-user-jmx.JSON
