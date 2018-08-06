#!/usr/bin/env bash

echo "install helm"
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get | bash
kubectl --namespace kube-system create sa tiller
kubectl create clusterrolebinding tiller \
    --clusterrole cluster-admin \
    --serviceaccount=kube-system:tiller

echo "create tiller namespace"
kubectl create namespace tiller

echo "preclean"
rm ca.* tiller.* helm.*

echo "create certs"
openssl genrsa -out ./ca.key.pem 4096
openssl req -key ca.key.pem -batch -new -x509 -days 7300 -sha256 -out ca.cert.pem -extensions v3_ca
# one per tiller host
openssl genrsa -out ./tiller.key.pem 4096
# one PER user (in this case helm is the user)
openssl genrsa -out ./helm.key.pem 4096
# create certificates for each of the keys
openssl req -key tiller.key.pem -new -batch -nodes -sha256 -out tiller.csr.pem
openssl req -key helm.key.pem -new -batch -nodes -sha256 -out helm.csr.pem
# sign each of the CSRs with the CA cert
openssl x509 -req -CA ca.cert.pem -CAkey ca.key.pem -CAcreateserial -in tiller.csr.pem -out tiller.cert.pem -days 365
openssl x509 -req -CA ca.cert.pem -CAkey ca.key.pem -CAcreateserial -in helm.csr.pem -out helm.cert.pem -days 365

echo "initialize helm"
helm init \
    --tiller-tls \
    --tiller-tls-cert ./tiller.cert.pem \
    --tiller-tls-key ./tiller.key.pem \
    --tiller-tls-verify \
    --tls-ca-cert ./ca.cert.pem \
    --tiller-namespace tiller \
    --service-account tiller
helm repo update

echo "verify helm"
kubectl get deploy,svc tiller-deploy -n kube-system
helm ls \
    --tls \
    --tls-ca-cert ca.cert.pem \
    --tls-cert helm.cert.pem \
    --tls-key helm.key.pem

echo "move certs"
# you move them so you don't need to include them with every call to helm
cp ca.cert.pem $(helm home)/ca.pem
cp helm.cert.pem $(helm home)/cert.pem
cp helm.key.pem $(helm home)/key.pem

echo "verify security"
helm ls --tls