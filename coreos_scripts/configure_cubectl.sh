#!/usr/bin/bash


MASTER_HOST=172.17.8.101
CA_CERT=/etc/kubernetes/ssl/
ADMIN_KEY=/etc/kubernetes/ssl/
ADMIN_CERT=/etc/kubernetes/ssl/

./kubectl config set-cluster default-cluster --server=https://${MASTER_HOST} --certificate-authority=${CA_CERT}
./kubectl config set-credentials default-admin --certificate-authority=${CA_CERT} --client-key=${ADMIN_KEY} --client-certificate=${ADMIN_CERT}
./kubectl config set-context default-system --cluster=default-cluster --user=default-admin
./kubectl config use-context default-system
