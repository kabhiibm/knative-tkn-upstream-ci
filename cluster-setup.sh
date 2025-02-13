#!/bin/bash

# Check if the Hosts file is provided as an argument
if [ -z "$1" ]; then
    echo "create/delete input not set."
    exit 1
fi

TIMESTAMP=$(date +%s)
K8S_BUILD_VERSION=$(curl https://storage.googleapis.com/k8s-release-dev/ci/latest.txt)
REGION=syd
ZONE="syd05"
SERVICE_ID="af3e8574-29ea-41a2-a9c5-e88cba5c5858"

if [[ "$1" == "create" ]]
then
    echo "Cluster creation started"
    kubetest2 tf --powervs-image-name CentOS9-Stream\
      --powervs-region $REGION --powervs-zone $ZONE \
      --powervs-service-id $SERVICE_ID \
      --powervs-ssh-key knative-ssh-key \
      --ssh-private-key ~/.ssh/ssh-key \
      --build-version $K8S_BUILD_VERSION \
      --cluster-name knative-$TIMESTAMP \
      --workers-count 2 \
      --playbook install-k8s-kn-tkn.yml \
      --up --auto-approve --retry-on-tf-failure 5 \
      --break-kubetest-on-upfail true \
      --powervs-memory 32
    
    export KUBECONFIG="$(pwd)/knative-$TIMESTAMP/kubeconfig"
    grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' $(pwd)/knative-$TIMESTAMP/hosts > HOSTS_IP
    source setup-environment.sh HOSTS_IP

elif [[ "$1" == "delete" ]]
then
    echo "Resources deletion started "
    kubetest2 tf --powervs-region syd --powervs-zone $ZONE \
      --powervs-service-id $SERVICE_ID \
      --ignore-cluster-dir true \
      --cluster-name knative-$TIMESTAMP \
      --down --auto-approve --ignore-destroy-errors
fi
