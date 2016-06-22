#! /bin/bash
MASTER_HOST=172.17.8.101
CA_CERT=/home/renhe/vagrant_data/coreos_scripts/tls/ca.pem
ADMIN_KEY=/home/renhe/vagrant_data/coreos_scripts/tls/admin-key.pem
ADMIN_CERT=/home/renhe/vagrant_data/coreos_scripts/tls/admin.pem
kubectl config set-cluster default-cluster --server=https://${MASTER_HOST} --certificate-authority=${CA_CERT}
kubectl config set-credentials default-admin --certificate-authority=${CA_CERT} --client-key=${ADMIN_KEY} --client-certificate=${ADMIN_CERT}
kubectl config set-context default-system --cluster=default-cluster --user=default-admin
kubectl config use-context default-system
