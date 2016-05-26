openssl genrsa -out kube-worker1-worker-key.pem 2048
WORKER_IP=172.17.8.101 openssl req -new -key kube-worker1-worker-key.pem -out kube-worker1-worker.csr -subj "/CN=kube-worker1" -config worker-openssl.cnf
WORKER_IP=172.17.8.101 openssl x509 -req -in kube-worker1-worker.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out kube-worker1-worker.pem -days 365 -extensions v3_req -extfile worker-openssl.cnf
