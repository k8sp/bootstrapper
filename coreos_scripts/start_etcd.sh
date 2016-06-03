#!/bin/bash

curl -X PUT -d "value={\"Network\":\"10.2.0.0/16\",\"Backend\":{\"Type\":\"vxlan\"}}" "172.17.8.101:2379/v2/keys/coreos.com/network/config"
