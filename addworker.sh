#!/bin/bash
echo ""
##export cluster admin kamaji
export KUBECONFIG=~/.kube/config

#tenant cluster parameters
export TENANT_NAMESPACE=default
export TENANT_NAME=teg-kube
export TENANT_VERSION=v1.26.7  #Version Available / Recomended = 1.27.0, 1.26.7, 1.25.12

#worker Tenant parameters
export WORKER_VERSION=1.26.7 #Version Available / Recomended = 1.27.0, 1.26.7, 1.25.12
export WORKER_FLAVOR=GP.1C2G
export AVAILABILITY_ZONE=AZ_Public01_DC2
export NETWORK=Public_Subnet02_DC2
export COUNT=2

#Proejct Tenant Parameters
export OS_AUTH_URL=https://jktosp-horizon.dcloud.co.id/identity/v3/
export OS_PROJECT_ID=8b39b22b07e644c5996ccb4ca196fb06
export OS_PROJECT_NAME="Cloud Development"
export OS_USER_DOMAIN_NAME="Default"
export OS_PROJECT_DOMAIN_ID="default"
export OS_USERNAME="teguh.imanto"
export OS_PASSWORD=D4t4c0mm@2023!!!
export OS_REGION_NAME="RegionOne"
export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3

kubectl get secrets -n ${TENANT_NAMESPACE} ${TENANT_NAME}-admin-kubeconfig -o json \
  | jq -r '.data["admin.conf"]' \
  | base64 --decode \
  > ${TENANT_NAME}.kubeconfig
  
echo "Create WORKER"
echo "Waiting..."

JOIN_CMD=$(kubeadm --kubeconfig=${TENANT_NAME}.kubeconfig token create --print-join-command)

cat << EOF | tee script.sh > /dev/null 2>&1
#cloud-config
debug: True
runcmd:
 - sudo apt-get update
 - sudo apt install -y kubeadm=${WORKER_VERSION}-00 kubelet=${WORKER_VERSION}-00 kubectl=${WORKER_VERSION}-00 --allow-downgrades --allow-change-held-packages
 - sudo apt-mark hold kubelet kubeadm kubectl
 - ${JOIN_CMD}
EOF

openstack server create --flavor ${WORKER_FLAVOR} --image "Worker Image Ubuntu 22.04" --network ${NETWORK} --security-group allow-all --availability-zone ${AVAILABILITY_ZONE} --key-name remote-server --min ${COUNT} --max ${COUNT} --user-data script.sh "${TENANT_NAME}-${TENANT_VERSION}-worker-add" > /dev/null 2>&1

sleep 2m 1s

echo "Create WORKER SUCCESS"

sleep 2s

echo ""
echo ""
echo "Node Cluster"
kubectl --kubeconfig=${TENANT_NAME}.kubeconfig get nodes
echo ""
echo ""

echo "Your Node has been Added !!!"
echo ""
echo "To Use your cluster = export KUBECONFIG=$PWD/${TENANT_NAME}.kubeconfig"
echo ""

rm -rf script.sh > /dev/null 2>&1
rm -rf createcluster.sh > /dev/null 2>&1
