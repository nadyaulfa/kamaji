#!/bin/bash
echo ""
##export cluster admin kamaji
export KUBECONFIG=~/.kube/config

#kamaji parameters
export KAMAJI_NAMESPACE=default

#tenant cluster parameters
export TENANT_NAMESPACE=default
export TENANT_NAME=kube-2-126
#Version Available = 1.27.0, 1.26.7, 1.25.12
export TENANT_VERSION=v1.26.1

#Worker Tenant parameters
#Version Available = 1.27.0, 1.26.7, 1.25.12
export WORKER_VERSION=1.26.1
export WORKER_FLAVOR=GP.2C4G
export AVAILABILITY_ZONE=AZ_Public01_DC3
export NETWORK=Public_Subnet02_DC3
export COUNT=2

echo "Deploy Cluster Kubernetes"
echo "Cluster Name: ${TENANT_NAME}"
echo "Version: ${TENANT_VERSION}"
echo ""
echo ""
echo "Create Tenant Control Plane"

kubectl create -f - <<EOF > /dev/null 2>&1
apiVersion: kamaji.clastix.io/v1alpha1
kind: TenantControlPlane
metadata:
  name: ${TENANT_NAME}
  namespace: ${TENANT_NAMESPACE}
spec:
  dataStore: default
  controlPlane:
    deployment:
      replicas: 3
    service:
      serviceType: LoadBalancer
  kubernetes:
    version: ${TENANT_VERSION}
    kubelet:
      cgroupfs: systemd
  networkProfile:
    port: 6443
  addons:
    coreDNS: {}
    kubeProxy: {}
    konnectivity:
      server:
        port: 8132
        resources: {}
      agent: {}
EOF

sleep 2m 10s

echo "Create Tenant Control Plane SUCCESS"


kubectl get secrets -n ${TENANT_NAMESPACE} ${TENANT_NAME}-admin-kubeconfig -o json \
  | jq -r '.data["admin.conf"]' \
  | base64 --decode \
  > ${TENANT_NAME}.kubeconfig
  
sleep 5  

echo "Create WORKER"

JOIN_CMD=$(kubeadm --kubeconfig=${TENANT_NAME}.kubeconfig token create --print-join-command)

sleep 2

cat << EOF | tee script.sh > /dev/null 2>&1
#cloud-config
debug: True
runcmd:
 - wget https://raw.githubusercontent.com/teghitsugaya/kamaji/main/${TENANT_VERSION}
 - sudo sh ${TENANT_VERSION}
 - ${JOIN_CMD}
EOF

sleep 2

export OS_AUTH_URL=https://jktosp-horizon.dcloud.co.id/identity/v3/
export OS_PROJECT_ID=55e36960719f41159aca054a14d2ba03
export OS_PROJECT_NAME="Infra Kamaji"
export OS_USER_DOMAIN_NAME="Default"
if [ -z "$OS_USER_DOMAIN_NAME" ]; then unset OS_USER_DOMAIN_NAME; fi
export OS_PROJECT_DOMAIN_ID="default"
if [ -z "$OS_PROJECT_DOMAIN_ID" ]; then unset OS_PROJECT_DOMAIN_ID; fi
unset OS_TENANT_ID
unset OS_TENANT_NAME
export OS_USERNAME="teguh.imanto"
export OS_PASSWORD=D4t4c0mm@2023!!!
export OS_REGION_NAME="RegionOne"
if [ -z "$OS_REGION_NAME" ]; then unset OS_REGION_NAME; fi
export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3

sleep 2

#openstack server create --flavor ${WORKER_FLAVOR} --image "Ubuntu Worker ${WORKER_VERSION}" --network ${NETWORK} --security-group kamaji-rules --availability-zone ${AVAILABILITY_ZONE} --key-name remote-server --min ${COUNT} --max ${COUNT} --user-data script.sh "${TENANT_NAME}-${TENANT_VERSION}-worker" > /dev/null 2>&1
openstack server create --flavor ${WORKER_FLAVOR} --image "Ubuntu 22.04 LTS" --network ${NETWORK} --security-group kamaji-rules --availability-zone ${AVAILABILITY_ZONE} --key-name remote-server --min ${COUNT} --max ${COUNT} --user-data script.sh "${TENANT_NAME}-${TENANT_VERSION}-worker" > /dev/null 2>&1

kubectl --kubeconfig=${TENANT_NAME}.kubeconfig apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/calico.yaml > /dev/null 2>&1

sleep 2m 1s

echo "Create WORKER SUCCESS"

echo ""
echo ""

sleep 1

kubectl --kubeconfig=${TENANT_NAME}.kubeconfig cluster-info

echo ""
echo ""

echo "Node Cluster"
kubectl --kubeconfig=${TENANT_NAME}.kubeconfig get nodes
echo ""
echo ""

echo "Your Cluster is Ready !!!"
echo ""
echo "To Use your cluster = export KUBECONFIG=$PWD/${TENANT_NAME}.kubeconfig"
echo ""

rm -rf script.sh > /dev/null 2>&1
rm -rf kamaji-script.sh > /dev/null 2>&1
