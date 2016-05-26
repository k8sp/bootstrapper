#!/usr/bin/bash
set -x

./kubectl get nodes
./kubectl get pods --namespace=kube-system | grep kube-dns-v11
./kubectl describe services
systemctl status kubelet.service
