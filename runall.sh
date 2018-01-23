#!/bin/bash


set -x

dcos package add marathon-lb
dcos marathon app add ./_dev_user-marathon2.JSON        
dcos marathon app add ./profbox7.JSON


