#!/usr/bin/bash

# load changed units
sudo systemctl daemon-reload

# start etcd service
curl -X PUT -d "value={\"Network\":\"10.2.0.0/16\",\"Backend\":{\"Type\":\"vxlan\"}}" "172.17.8.101:2379/v2/keys/coreos.com/network/config"

# start kubelet
sudo systemctl start kubelet
sudo systemctl enable kubelet
